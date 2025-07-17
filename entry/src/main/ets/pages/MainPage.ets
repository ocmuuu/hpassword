import router from '@ohos.router'
import pasteboard from '@ohos.pasteboard'
import { KdbxCore, KdbxCoreManager } from '../utils/KdbxCore'
import { KdbxQuery } from '../utils/KdbxQuery'
import { KdbxEntryManager } from '../utils/KdbxEntryManager'
import { KdbxGroupManager } from '../utils/KdbxGroupManager'
import { DatabaseFileManager } from '../utils/DatabaseFileManager'
import { OperationResult, EntryCreateParams, EntryUpdateParams, GroupCreateParams } from '../utils/KdbxTypes'
import PreferencesUtil from '../utils/PreferencesUtil'
import { TemplateManager, CategoryTemplate } from '../templates/index'
import { EntryConverter, EntryItem } from '../utils/EntryConverter'
import { FieldInfoHelper, FieldInfo, RenderField } from '../templates/FieldInfoHelper'
import { SearchHelper, SearchState } from '../utils/SearchHelper'
import { LoginTemplate } from '../templates/Login'
import { FieldSpec } from '../templates/TemplateTypes'
import { PasswordGenerator } from '../utils/PasswordGenerator'
import { LayoutPreferencesUtil } from '../utils/LayoutPreferencesUtil'
import { EntryService } from '../utils/EntryService'
import { DatabaseFileService } from '../utils/DatabaseFileService'
import { ClipboardUtil } from '../utils/ClipboardUtil'
import { MainPageDataService } from '../utils/MainPageDataService'
import { AutoCloseManager } from '../utils/AutoCloseManager'

// 密码库项目类型（配置项中的原始数据）
interface DatabaseItem {
  id: string
  name: string
  path: string
  lastModified: string
  size: number
}

// 侧边栏项目类型
interface SidebarItem {
  id: string
  title: string
  icon: Resource
  type: 'special' | 'group' | 'recycle' | 'divider'
  count?: number
  parentId?: string
}


@Entry
@Component
struct MainPage {
  @State private kdbxCore: KdbxCore | null = null
  @State private kdbxQuery: KdbxQuery | null = null
  @State private kdbxEntryManager: KdbxEntryManager | null = null
  @State private kdbxGroupManager: KdbxGroupManager | null = null
  @State private databaseFileManager: DatabaseFileManager | null = null
  
  // 数据状态
  @State private databaseName: string = '密码库'  // 数据库名称
  @State private sidebarItems: SidebarItem[] = []
  @State private fixedSidebarItems: SidebarItem[] = []  // 固定在上方的项目
  @State private scrollableSidebarItems: SidebarItem[] = []  // 可滚动的项目
  @State private entryItems: EntryItem[] = []
  @State private selectedSidebarId: string | null = null
  @State private selectedEntryId: string | null = null
  @State private selectedEntry: EntryItem | null = null
  @State private passwordVisible: Set<string> = new Set()  // 记录哪些密码字段是可见的
  @State private sortedFields: string[] = []  // 排序后的字段键列表（保留备用）
  @State private renderFields: RenderField[] = [] // 供 UI 直接渲染的字段数据
  @State private updateCounter: number = 0 // 强制更新计数器
  @State private hoverEntryId: string | null = null  // 鼠标悬停的条目ID
  @State private hoverFieldKey: string | null = null  // 详情面板悬停字段Key
  @State private showCopySuccessToast: boolean = false  // 复制成功提醒显示状态
  @State private successToastMessage: string = '复制成功'  // 成功提醒消息
  
  // 表单状态
  @State private isAddingEntry: boolean = false  // 是否正在添加新条目
  @State private isEditingEntry: boolean = false  // 是否正在编辑条目
  @State private formData: Record<string, string> = {}  // 表单数据
  @State private isSubmitting: boolean = false  // 是否正在提交表单
  @State private validationError: string | null = null  // 表单验证错误
  @State private selectedTemplate: CategoryTemplate = LoginTemplate  // 当前选定的模板
  @State private availableTemplates: CategoryTemplate[] = TemplateManager.getAllTemplates()  // 所有可供选择的模板
  @State private showTemplateDropdown: boolean = false  // 模板下拉框显示状态
  @State private hoverTemplateName: string | null = null  // 下拉模板项 hover 状态
  
  // 搜索状态（由 SearchHelper 管理）
  @State private searchState: SearchState = {
    query: '',
    isSearching: false,
    results: []
  }
  
  // 搜索助手
  private searchHelper: SearchHelper = new SearchHelper()
  
  // 布局状态
  @State private isFirstColumnCollapsed: boolean = false
  @State private firstColumnWidth: number = 200
  @State private secondColumnWidth: number = 250
  @State private isInitialized: boolean = false
  
  // 加载状态
  @State private isLoading: boolean = false
  @State private error: string | null = null
  
  // 复制成功提醒定时器
  private copySuccessTimer: number | null = null
  
  // 表单验证错误提醒定时器
  private validationErrorTimer: number | null = null

  async aboutToAppear() {
    try {
      const context = getContext(this) as Context

      let initialized = PreferencesUtil.initSync(context)
      if (!initialized) {
        initialized = await PreferencesUtil.init(context)
      }
      
      if (initialized) {
        // 恢复布局状态
        const layout = await LayoutPreferencesUtil.restoreLayoutStates()
        this.isFirstColumnCollapsed = layout.collapsed
        this.firstColumnWidth = layout.firstWidth
        this.secondColumnWidth = layout.secondWidth
      }
      
      // 从全局管理器获取KdbxCore实例
      const kdbxCore = KdbxCoreManager.getInstance().getCurrentKdbxCore()
      
      if (kdbxCore) {
        this.kdbxCore = kdbxCore
        const db = kdbxCore.getDatabase()
        if (db) {
          this.kdbxQuery = new KdbxQuery(db)
          this.kdbxEntryManager = new KdbxEntryManager(db)
          this.kdbxGroupManager = new KdbxGroupManager(db)

          if (db.meta && db.meta.name) {
            this.databaseName = db.meta.name
          }

          const context = getContext(this) as Context
          this.databaseFileManager = new DatabaseFileManager(context)
        }

        await this.initializeData()
      } else {
        this.error = '数据库实例获取失败'
      }
      
      this.searchHelper.setCallback((state: SearchState) => {
        this.searchState = state
      })
      
      this.isInitialized = true

      AutoCloseManager.getInstance().init(() => this.autoCloseDatabase())
    } catch (error) {
      this.error = `初始化失败: ${error}`
      this.isInitialized = true
    }
  }

  /**
   * 初始化数据
   */
  private async initializeData() {
    try {
      this.isLoading = true
      await this.initializeSidebarItems()
      
      this.selectedSidebarId = 'all_entries'
      await this.loadEntriesForSidebar('all_entries')
      
    } catch (error) {
      this.error = `数据初始化失败: ${error}`
    } finally {
      this.isLoading = false
    }
  }

  /**
   * 初始化侧边栏项目
   */
  private async initializeSidebarItems() {
    if (!this.kdbxQuery) {
      return
    }
    const result = await MainPageDataService.buildSidebarItems(this.kdbxQuery)
    this.sidebarItems = result.allItems
    this.fixedSidebarItems = result.fixedItems
    this.scrollableSidebarItems = result.scrollableItems
  }

  /**
   * 为侧边栏项目加载条目
   */
  private async loadEntriesForSidebar(sidebarId: string) {
    try {
      if (!this.kdbxQuery) {
        return
      }
      const entries = await MainPageDataService.fetchEntriesForSidebar(this.kdbxQuery, this.sidebarItems, sidebarId)
      this.entryItems = entries
    } catch (error) {
      console.error('MainPage', '加载条目失败:', error)
    }
  }

  /**
   * 侧边栏项目点击处理
   */
  private async onSidebarItemClick(item: SidebarItem) {
    AutoCloseManager.getInstance().reset()
    
    if (item.type === 'divider') {
      return
    }
    
    this.searchHelper.clearSearch()
    
    this.selectedSidebarId = item.id
    this.selectedEntryId = null
    this.selectedEntry = null
    
    await this.loadEntriesForSidebar(item.id)
     if (PreferencesUtil.isInitialized()) {
       PreferencesUtil.saveSelectedKdbxSidebarIdSync(item.id)
     }
  }

  /**
   * 条目项目点击处理
   */
  private onEntryItemClick(entry: EntryItem) {
    try {
      AutoCloseManager.getInstance().reset()
      this.updateSelectedEntry(entry)
      
      if (this.searchState.isSearching) {
        this.searchHelper.clearSearch()
        if (entry.groupId && entry.groupId !== this.selectedSidebarId) {
          this.selectedSidebarId = entry.groupId
          this.loadEntriesForSidebar(entry.groupId).then(() => {
            const updatedEntry = this.entryItems.find(item => item.id === entry.id)
            if (updatedEntry) {
              this.updateSelectedEntry(updatedEntry)
            }
          }).catch((error: ESObject) => {
            console.error('MainPage', '加载分组条目失败:', error)
          })
        }
      }
    } catch (error) {
      console.error('MainPage', '条目点击处理失败:', error)
    }
  }
  
  /**
   * 安全地更新 selectedEntry，确保触发响应式更新
   */
  private updateSelectedEntry(entry: EntryItem): void {
    this.updateCounter++
    
    this.selectedEntry = null
    this.renderFields = []
    this.passwordVisible = new Set()
    
    setTimeout(() => {
      const newFields = new Map<string, string>()
      if (entry.fields) {
        entry.fields.forEach((value, key) => {
          newFields.set(key, value)
        })
      }
      
      this.selectedEntry = {
        id: entry.id,
        title: entry.title,
        username: entry.username,
        notes: entry.notes,
        url: entry.url,
        icon: entry.icon,
        lastModified: entry.lastModified,
        groupId: entry.groupId,
        groupName: entry.groupName,
        fields: newFields
      }
      this.selectedEntryId = entry.id
      
      if (entry.groupId === 'random_password') {
        const pwdType = Number(newFields.get('Type') || 1)
        const renderList: RenderField[] = PasswordGenerator.buildRenderFields(pwdType)
        this.renderFields = renderList
        this.sortedFields = renderList.map(f => f.key)
      } else {
        const rf = EntryService.buildRenderFields(this.selectedEntry)
        this.renderFields = rf.renderFields
        this.sortedFields = rf.sortedKeys
      }
    }, 1)
  }

  /**
   * 切换第一栏折叠状态
   */
  private onToggleFirstColumn() {
    AutoCloseManager.getInstance().reset()
    
    this.isFirstColumnCollapsed = !this.isFirstColumnCollapsed
    
    LayoutPreferencesUtil.saveFirstColumnCollapseState(this.isFirstColumnCollapsed)
  }

  /**
   * 返回首页：保存并关闭数据库，跳转到 Index 页面并重置密码输入
   */
  private async onBackToHome() {
    AutoCloseManager.getInstance().clear()

    await DatabaseFileService.returnToIndex(this.kdbxCore, this.databaseFileManager)
  }

  /**
   * 创建侧边栏项目视图
   */
  @Builder
  private SidebarItemView(item: SidebarItem) {
    if (item.type === 'divider') {
      Divider()
        .strokeWidth(1)
        .color('#e0e0e0')
        .margin({ left: 16, right: 16, top: 8, bottom: 8 })
    } else {
      Row() {
        Image(item.icon)
          .width(20)
          .height(20)
          .margin({ right: 12 })
          .fillColor(item.type === 'special' ? '#007AFF' : '#666666')

        Text(item.title)
          .fontSize(17)
          .fontWeight(item.type === 'special' ? FontWeight.Medium : FontWeight.Normal)
          .fontColor('#000')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

      }
      .width('100%')
      .height(40)
      .padding({ left: 16, right: 16 })
      .margin({ top: item.id === 'starred' ? 12 : 0, bottom: item.id === 'all_entries' ? 4 : 0 })
      .backgroundColor(this.selectedSidebarId === item.id ? '#f0f7ff' : '#fff')
      .alignItems(VerticalAlign.Center)
    }
  }

  /**
   * 创建条目项目视图
   */
  @Builder
  private EntryItemView(entry: EntryItem) {
    Row() {
      if (!this.isInRecycleBin()) {
        Image(entry.icon)
          .width(20)
          .height(20)
          .margin({ right: 12 })
          .fillColor('#666666')
      }

      Column() {
        Text(entry.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.searchHelper.containsSearchKeyword(entry.title) ? '#007AFF' : '#000')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)

        if (entry.username) {
          Text(entry.username)
            .fontSize(14)
            .fontColor(this.searchHelper.containsSearchKeyword(entry.username) ? '#007AFF' : '#666')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Start)
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: this.isInRecycleBin() ? 12 : 0 })
    }
    .width('100%')
    .height(60)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.selectedEntryId === entry.id ? '#f0f7ff' : (this.hoverEntryId === entry.id ? '#f5f5f5' : '#fff'))
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onEntryItemClick(entry)
    })
  }

  /**
   * 创建详情面板视图
   */
  @Builder
  private DetailPanelView() {
    if (this.isAddingEntry || this.isEditingEntry) {
      this.AddFormView()
    } else if (this.selectedEntry) {
      Column() {
          Row() {
            Text(this.selectedEntry.title + (this.updateCounter > 0 ? '' : ''))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000')
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (!this.isInRecycleBin()) {
            Button() {
              Image(EntryService.isEntryStarred(this.selectedEntry) ? $r('app.media.star') : $r('app.media.unstar'))
                .width(20)
                .height(20)
                .fillColor(EntryService.isEntryStarred(this.selectedEntry) ? '#FFD700' : '#666')
            }
            .backgroundColor('transparent')
            .padding(4)
            .margin({ right: 4 })
            .stateEffect(false)
            .onClick(async () => {
              AutoCloseManager.getInstance().reset()
              
              if (this.selectedEntry && this.kdbxEntryManager) {
                const kdbxEntry: ESObject | null = await this.getKdbxEntryById(this.selectedEntry.id);
                if (kdbxEntry) {
                  const result = this.kdbxEntryManager.toggleEntryStarred(kdbxEntry);
                  if (result.success) {
                    await DatabaseFileService.saveDatabaseToFile(this.kdbxCore, this.databaseFileManager);
                    
                    await this.loadEntriesForSidebar(this.selectedSidebarId || 'all_entries');
                    const updatedSelectedEntry = this.entryItems.find(item => item.id === this.selectedEntry?.id);
                    if (updatedSelectedEntry) {
                      this.updateSelectedEntry(updatedSelectedEntry);
                    }
                  }
                }
              }
            })

            // 编辑按钮
            Button() {
              Image($r('app.media.edit'))
                .width(20)
                .height(20)
                .fillColor('#007AFF')
            }
            .backgroundColor('transparent')
            .padding(4)
            .stateEffect(false)
            .margin({ right: 4 })
            .onClick(() => {
              AutoCloseManager.getInstance().reset()

              this.showEditForm()
            })
          }

          // 删除按钮（回收站和非回收站都有，但功能不同）
          Button() {
            Image($r('app.media.trash'))
              .width(20)
              .height(20)
              .fillColor('#ff4444')
          }
          .backgroundColor('transparent')
          .padding(4)
          .stateEffect(false)
          .onClick(async () => {
            AutoCloseManager.getInstance().reset()
            
            if (!this.selectedEntry || !this.kdbxEntryManager) {
              return
            }

            const kdbxEntry: ESObject | null = await this.getKdbxEntryById(this.selectedEntry.id)
            if (!kdbxEntry) {
              return
            }

            const delResult = this.kdbxEntryManager.deleteEntry(kdbxEntry as ESObject)
            
            if (delResult.success) {
              await DatabaseFileService.saveDatabaseToFile(this.kdbxCore, this.databaseFileManager);

              await this.initializeSidebarItems()

              await this.loadEntriesForSidebar(this.selectedSidebarId || 'all_entries')

              this.selectedEntry = null
              this.selectedEntryId = null
              console.log('MainPage', 'UI更新完成')
            } else {
              console.error('MainPage', '删除失败:', delResult.error)
            }
          })

          Button() {
            Image($r('app.media.information'))
              .width(20)
              .height(20)
              .fillColor('#007AFF')
          }
          .backgroundColor('transparent')
          .padding(4)
          .stateEffect(false)
          .onClick(() => {
            router.pushUrl({
              url: 'pages/HelpPage'
            })
          })
        }
        .width('100%')
        .height(50)
        .padding({ left: 16, right: 16 })
        .backgroundColor('#f8f9fa')
        .border({ width: { bottom: 1 }, color: '#e0e0e0' })

        Scroll() {
          Column() {
            ForEach(this.renderFields, (field: RenderField) => {
              this.RenderFieldItem(field)
            }, (field: RenderField) => field.key + '_' + this.updateCounter)

            Blank()
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 16 })
          .justifyContent(FlexAlign.Start)
        }
        .layoutWeight(1)
        .backgroundColor('#fff')
        
        if (this.showCopySuccessToast) {
          Row() {
            Image($r('app.media.success'))
              .width(16)
              .height(16)
              .fillColor('#52c41a')
              .margin({ right: 8 })
              
            Text(this.successToastMessage)
              .fontSize(14)
              .fontColor('#52c41a')
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .height(40)
          .padding({ left: 20, right: 20 })
          .backgroundColor('#f6ffed')
          .border({ width: { top: 1 }, color: '#b7eb8f' })
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
          .transition(TransitionEffect.opacity(1).animation({ duration: 300 }))
        }
      }
      .width('100%')
      .height('100%')
    } else {
      Row() {
        Blank()
          .layoutWeight(1)

        Button() {
          Image($r('app.media.information'))
            .width(20)
            .height(20)
            .fillColor('#007AFF')
        }
        .backgroundColor('transparent')
        .padding(4)
        .stateEffect(false)
        .onClick(() => {
          router.pushUrl({
            url: 'pages/HelpPage'
          })
        })
      }
      .width('100%')
      .height(50)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#f8f9fa')
      .border({ width: { bottom: 1 }, color: '#e0e0e0' })

      // 空状态
      Column() {
        Column() {
          Image($r('app.media.startIcon'))
            .width(80)
            .height(80)
            .opacity(0.3)
            .margin({ bottom: 16 })

          Text('选择一个条目查看详情')
            .fontSize(16)
            .fontColor('#999')

          Text('从左侧列表中选择要查看的条目')
            .fontSize(14)
            .fontColor('#ccc')
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Start)
        .padding({ top: 60 })
        
        if (this.showCopySuccessToast) {
          Row() {
            Image($r('app.media.information'))
              .width(16)
              .height(16)
              .fillColor('#52c41a')
              .margin({ right: 8 })
              
            Text(this.successToastMessage)
              .fontSize(14)
              .fontColor('#52c41a')
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .height(40)
          .padding({ left: 20, right: 20 })
          .backgroundColor('#f6ffed')
          .border({ width: { top: 1 }, color: '#b7eb8f' })
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
          .transition(TransitionEffect.opacity(1).animation({ duration: 300 }))
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#fff')
    }
  }

  /**
   * 创建详情字段视图
   */
  @Builder
  private DetailFieldView(label: string, value: string) {
    Column() {
      Row() {
        Text(label)
          .fontSize(16)
          .fontColor('#666')
          .fontWeight(FontWeight.Medium)
          .width(120)

        Text(value)
          .fontSize(16)
          .fontColor('#000')
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
          .margin({ left: 8 })

        Button('复制')
          .fontSize(12)
          .backgroundColor('#f0f0f0')
          .fontColor('#000')
          .borderRadius(3)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .opacity(this.hoverFieldKey === label ? 1 : 0)
          .onClick(() => {
            AutoCloseManager.getInstance().reset()
            
            this.copyToClipboard(value)
          })
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      .backgroundColor(this.hoverFieldKey === label ? '#f5f5f5' : '#fff')
      .alignItems(VerticalAlign.Center)
      .onHover((isHover: boolean) => {
        this.hoverFieldKey = isHover ? label : (this.hoverFieldKey === label ? null : this.hoverFieldKey)
      })

      Divider()
        .strokeWidth(1)
        .color('#f0f0f0')
        .margin({ top: 4, bottom: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      AutoCloseManager.getInstance().reset();
      this.copyToClipboard(value);
    })
  }

  /**
   * 创建密码字段视图（带显示/隐藏功能）
   */
  @Builder
  private PasswordFieldView(label: string, value: string, fieldKey: string) {
    Column() {
      Row() {
        Text(label)
          .fontSize(16)
          .fontColor('#666')
          .fontWeight(FontWeight.Medium)
          .width(120)

        Text(this.passwordVisible.has(fieldKey) ? value : '••••••••')
          .fontSize(16)
          .fontColor('#000')
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
          .fontFamily('monospace')
          .margin({ left: 8 })

        Button('复制')
          .fontSize(12)
          .backgroundColor('#f0f0f0')
          .fontColor('#000')
          .borderRadius(3)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .opacity(this.hoverFieldKey === fieldKey ? 1 : 0)
          .onClick(() => {
            AutoCloseManager.getInstance().reset()
            
            this.copyToClipboard(value)
          })

        Button(this.passwordVisible.has(fieldKey) ? '隐藏' : '显示')
          .fontSize(12)
          .backgroundColor('#f0f0f0')
          .fontColor('#000')
          .padding({ left: 6, right: 6, top: 4, bottom: 4 })
          .opacity(this.hoverFieldKey === fieldKey ? 1 : 0)
          .onClick(() => {
            AutoCloseManager.getInstance().reset()
            
            if (this.passwordVisible.has(fieldKey)) {
              this.passwordVisible.delete(fieldKey);
            } else {
              this.passwordVisible.add(fieldKey);
            }
            this.passwordVisible = new Set(this.passwordVisible);
          })
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      .backgroundColor(this.hoverFieldKey === fieldKey ? '#f5f5f5' : '#fff')
      .alignItems(VerticalAlign.Center)
      .onHover((isHover: boolean) => {
        this.hoverFieldKey = isHover ? fieldKey : (this.hoverFieldKey === fieldKey ? null : this.hoverFieldKey)
      })

      Divider()
        .strokeWidth(1)
        .color('#f0f0f0')
        .margin({ top: 4, bottom: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      AutoCloseManager.getInstance().reset();
      this.copyToClipboard(value);
    })
  }

  /**
   * 渲染单个字段，根据类型选择合适组件
   */
  @Builder
  private RenderFieldItem(field: RenderField) {
    if (field.type === 'password') {
      this.PasswordFieldView(field.label, field.value, field.key)
    } else {
      this.DetailFieldView(field.label, field.value)
    }
  }

  /**
   * 创建添加表单视图
   */
  @Builder
  private AddFormView() {
    Column() {
      Row() {
        Text(`${this.isEditingEntry ? '编辑' : '新建'}${this.selectedTemplate.name}条目`)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#000')
          .layoutWeight(1)

        Button('取消')
          .fontSize(14)
          .backgroundColor('#f0f0f0')
          .fontColor('#666')
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
          .borderRadius(2)
          .height(32)
          .border({ width: 1, color: '#000' })
          .margin({ right: 5 })
          .onClick(() => {
            if (this.isEditingEntry) {
              this.hideEditForm()
            } else {
              this.hideAddForm()
            }
          })

        // 保存按钮
        Button(this.isSubmitting ? '保存中...' : '保存')
          .fontSize(14)
          .backgroundColor('#6FA8FF')
          .fontColor('#fff')
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
          .borderRadius(2)
          .height(32)
          .border({ width: 1, color: '#000' })
          .enabled(!this.isSubmitting)
          .onClick(() => {
            if (this.isEditingEntry) {
              this.submitEditForm()
            } else {
              this.submitForm()
            }
          })
      }
      .width('100%')
      .height(50)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#f8f9fa')
      .border({ width: { bottom: 1 }, color: '#e0e0e0' })

      Scroll() {
        Column() {
          Column() {
            Row() {

              Button() {
                Row() {
                  Image(EntryConverter.getTemplateIcon(this.selectedTemplate.name))
                    .width(18)
                    .height(18)
                    .margin({ right: 6 })

                  Text(this.selectedTemplate.name)
                    .fontSize(18)
                    .fontColor('#000')

                  if (!this.isEditingEntry) {
                    Image(this.showTemplateDropdown ? $r('app.media.arrow_up') : $r('app.media.arrow_down'))
                      .width(20)
                      .height(20)
                      .margin({ left: 6 })
                  }
                }
                .alignItems(VerticalAlign.Center)
              }
              .backgroundColor('#f8f8f8')
              .padding({ left: 12, right: 12, top: 4, bottom: 4 })
              .borderRadius(1)
              .border({ width: 1, color: '#cccccc' })
              .enabled(!this.isEditingEntry)
              .onClick(() => {
                if (this.isEditingEntry) {
                  return
                }
                this.showTemplateDropdown = !this.showTemplateDropdown
              })

              Text('模板')
                .fontSize(18)
                .fontColor('#000')
                .fontWeight(FontWeight.Medium)
                .margin({ left: 4 })
            }
            .width('100%')
            .height(40)
            .alignItems(VerticalAlign.Center)
            .margin({ left: 4 })
            .margin({ bottom: 8 })

            if (this.showTemplateDropdown && !this.isEditingEntry) {
              Scroll() {
                Column() {
                  ForEach(this.availableTemplates, (tpl: CategoryTemplate) => {
                    Row() {
                      Image(EntryConverter.getTemplateIcon(tpl.name))
                        .width(18)
                        .height(18)
                        .margin({ right: 8 })

                      Text(tpl.name)
                        .fontSize(18)
                        .fontColor('#000')
                        .layoutWeight(1)
                    }
                    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                    .width('100%')
                    .backgroundColor(tpl.name === this.selectedTemplate.name ? '#e6f2ff' : (tpl.name === this.hoverTemplateName ? '#f5f5f5' : '#fff'))
                    .alignItems(VerticalAlign.Center)
                    .onHover((isHover: boolean) => {
                      this.hoverTemplateName = isHover ? tpl.name : (this.hoverTemplateName === tpl.name ? null : this.hoverTemplateName)
                    })
                    .onClick(() => {
                        this.selectedTemplate = tpl
                        // 重新初始化表单数据
                        this.formData = {}
                        tpl.fields.forEach((f: FieldSpec) => {
                          this.formData[f.key] = ''
                        })
                        this.showTemplateDropdown = false
                      })
                  }, (tpl: CategoryTemplate) => tpl.name)
                }
                .width('100%')
              }
              .width('60%')
              .height(190)
              .border({ width: 1, color: '#ddd' })
              .backgroundColor('#fff')
              .margin({ bottom: 16 })
              .margin({ left: 4 })
              .align(Alignment.TopStart)
            }
          }
          .width('100%')
          .margin({ bottom: 8 })
          .alignItems(HorizontalAlign.Start)

          Divider()
            .strokeWidth(1)
            .color('#e0e0e0')
            .margin({ top: 4, bottom: 16 })

          ForEach(this.selectedTemplate.fields, (field: FieldSpec) => {
            Column() {
              Row() {
                Text(field.label)
                  .fontSize(16)
                  .fontColor('#333')
                  .fontWeight(FontWeight.Medium)
                  .margin({ bottom: 8 })

                if (field.key === 'Title' || field.key === 'UserName' || field.key === 'Password') {
                  Text('*')
                    .fontSize(16)
                    .fontColor('#ff4444')
                    .margin({ left: 4 })
                }
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              if (field.key === 'Notes') {
                TextArea({ 
                  placeholder: `请输入${field.label}`,
                  text: this.formData[field.key] || ''
                })
                  .fontSize(16)
                  .border({ width: 1, color: '#ddd' })
                  .borderRadius(4)
                  .padding(12)
                  .height(80)
                  .onChange((value: string) => {
                    this.formData[field.key] = value
                  })
              } else {
                TextInput({ 
                  placeholder: `请输入${field.label}`,
                  text: this.formData[field.key] || ''
                })
                  .fontSize(16)
                  .border({ width: 1, color: '#ddd' })
                  .borderRadius(4)
                  .padding(12)
                  .type(field.protected ? InputType.Password : InputType.Normal)
                  .onChange((value: string) => {
                    this.formData[field.key] = value
                  })
              }
            }
            .width('100%')
            .margin({ bottom: 16 })
            .alignItems(HorizontalAlign.Start)
          }, (field: FieldSpec) => field.key)

          Blank()
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 16 })
        .justifyContent(FlexAlign.Start)
      }
      .layoutWeight(1)
      .backgroundColor('#fff')
      
      if (this.validationError) {
        Row() {
          Image($r('app.media.information'))
            .width(16)
            .height(16)
            .fillColor('#ff4444')
            .margin({ right: 8 })
            
          Text(this.validationError)
            .fontSize(14)
            .fontColor('#ff4444')
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .height(40)
        .padding({ left: 20, right: 20 })
        .backgroundColor('#fef2f2')
        .border({ width: { top: 1 }, color: '#fecaca' })
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .transition(TransitionEffect.opacity(1).animation({ duration: 300 }))
      }
    }
    .width('100%')
    .height('100%')
  }


  /**
   * 通过ID获取KdbxEntry对象
   */
  private async getKdbxEntryById(entryId: string): Promise<ESObject | null> {
    if (!this.kdbxQuery) {
      return null;
    }

    try {
      const result: OperationResult<ESObject> = this.kdbxQuery.findEntryById(entryId);
      if (result.success && result.data) {
        return result.data as ESObject;
      }
    } catch (error) {
      console.error('MainPage', '获取条目失败:', error);
    }
    
    return null;
  }

  /**
   * 复制文本到剪贴板
   */
  private async copyToClipboard(text: string): Promise<void> {
    try {
      await ClipboardUtil.copy(text)
      
      if (this.copySuccessTimer !== null) {
        clearTimeout(this.copySuccessTimer)
        this.copySuccessTimer = null
      }
      
      this.successToastMessage = '复制成功'
      this.showCopySuccessToast = true
      
      this.copySuccessTimer = setTimeout(() => {
        this.showCopySuccessToast = false
        this.copySuccessTimer = null
      }, 2500)
    } catch (error) {
      console.error('MainPage', '复制失败:', error)
    }
  }

  /**
   * 显示添加表单
   */
  private showAddForm() {
    this.isEditingEntry = false
    this.isAddingEntry = true
    this.selectedEntry = null
    this.selectedEntryId = null

    let templateToUse: CategoryTemplate = LoginTemplate
    const sidebarItem = this.sidebarItems.find(item => item.id === this.selectedSidebarId)
    if (sidebarItem && sidebarItem.type === 'group') {
      const matched = TemplateManager.getTemplateByGroupName(sidebarItem.title)
      if (matched) {
        templateToUse = matched
      }
    }

    this.selectedTemplate = templateToUse

    this.formData = {}
    this.selectedTemplate.fields.forEach((field: FieldSpec) => {
      this.formData[field.key] = ''
    })

    if (this.isInRecycleBin()) {
      this.showValidationError('回收站中无法新建条目')
      return
    }
  }

  /**
   * 隐藏添加表单
   */
  private hideAddForm() {
    this.isAddingEntry = false
    this.formData = {}
    this.validationError = null
    if (this.validationErrorTimer !== null) {
      clearTimeout(this.validationErrorTimer)
      this.validationErrorTimer = null
    }
  }

  /**
   * 显示编辑表单
   */
  private showEditForm() {
    if (!this.selectedEntry) {
      return
    }

    this.isEditingEntry = true
    this.isAddingEntry = false

    const tpl: CategoryTemplate | null = TemplateManager.getTemplateByGroupName(this.selectedEntry.groupName || '') ?? null
    this.selectedTemplate = tpl ? tpl : LoginTemplate

    this.formData = {}
    this.selectedTemplate.fields.forEach((field: FieldSpec) => {
      switch (field.key) {
        case 'Title':
          this.formData[field.key] = this.selectedEntry?.title || ''
          break
        case 'UserName':
          this.formData[field.key] = this.selectedEntry?.username || ''
          break
        case 'Password':
          this.formData[field.key] = this.selectedEntry?.fields?.get('Password') || ''
          break
        case 'URL':
          this.formData[field.key] = this.selectedEntry?.url || ''
          break
        case 'Notes':
          this.formData[field.key] = this.selectedEntry?.notes || ''
          break
        default:
          this.formData[field.key] = this.selectedEntry?.fields?.get(field.key) || ''
      }
    })
  }

  /**
   * 隐藏编辑表单
   */
  private hideEditForm() {
    this.isEditingEntry = false
    this.formData = {}
    this.validationError = null
    if (this.validationErrorTimer !== null) {
      clearTimeout(this.validationErrorTimer)
      this.validationErrorTimer = null
    }
  }

  /**
   * 显示验证错误提醒
   */
  private showValidationError(message: string) {
    if (this.validationErrorTimer !== null) {
      clearTimeout(this.validationErrorTimer)
      this.validationErrorTimer = null
    }
    
    this.validationError = message
    
    this.validationErrorTimer = setTimeout(() => {
      this.validationError = null
      this.validationErrorTimer = null
    }, 3000)
  }

  /**
   * 提交表单
   */
  private async submitForm() {
    if (!this.kdbxEntryManager || !this.kdbxGroupManager || !this.kdbxCore) {
      console.error('MainPage', '数据库管理器未初始化')
      return
    }

    const titleKey = this.selectedTemplate.fields.some(f => f.key === 'Title') ? 'Title' : this.selectedTemplate.fields[0]?.key
    const baseRequired: string[] = titleKey ? [titleKey] : []
    const extraRequired: string[] = ['UserName', 'Password']
    const requiredKeys: string[] = baseRequired.concat(
      extraRequired.filter(key => this.selectedTemplate.fields.some(f => f.key === key))
    )

    const missingKeys: string[] = requiredKeys.filter(key => !this.formData[key])

    if (missingKeys.length > 0) {
      const missingLabels = this.selectedTemplate.fields
        .filter(f => missingKeys.includes(f.key))
        .map(f => f.label || f.key)
        .join('、')

      console.error('MainPage', `请填写必填字段：${missingLabels}`)
      this.showValidationError(`请填写必填字段：${missingLabels}`)
      return
    }

    this.isSubmitting = true

    try {
      let targetGroup: ESObject | undefined = undefined
      const allGroupsResult = await this.kdbxQuery?.getAllGroups()
      if (allGroupsResult?.success && allGroupsResult.data) {
        targetGroup = allGroupsResult.data.find((g: ESObject) => (g.name as string) === this.selectedTemplate.name)
      }

      if (!targetGroup) {
        let groupId = this.selectedSidebarId
        if (!groupId || groupId === 'all_entries' || groupId === 'starred') {
          if (allGroupsResult?.success && allGroupsResult.data && allGroupsResult.data.length > 0) {
            const firstNormal = allGroupsResult.data.find((group: ESObject) => (group.name as string) !== 'Recycle Bin')
            if (firstNormal) {
              groupId = (firstNormal.uuid as ESObject).id as string
            }
          }
        }

        if (groupId && allGroupsResult?.success && allGroupsResult.data) {
          targetGroup = allGroupsResult.data.find((g: ESObject) => (g.uuid as ESObject).id === groupId)
        }
      }

      if (!targetGroup && this.kdbxGroupManager) {
        const defaultGroup = this.kdbxCore?.getDatabase()?.getDefaultGroup()
        
        const createGroupResult = this.kdbxGroupManager.createGroup({
          name: this.selectedTemplate.name,
          notes: `自动创建的${this.selectedTemplate.name}模板组`,
          parentGroup: defaultGroup
        })
        
        if (createGroupResult.success && createGroupResult.data) {
          targetGroup = createGroupResult.data as ESObject
          console.log('MainPage', `已创建新组: ${this.selectedTemplate.name}`)
        } else {
          console.warn('MainPage', `创建组失败: ${createGroupResult.error}`)
        }
      }

      const titleValue: string = this.formData[titleKey] || ''

      const createParams: EntryCreateParams = {
        title: titleValue,
        username: this.formData['UserName'],
        password: this.formData['Password'],
        url: this.formData['URL'] || '',
        notes: this.formData['Notes'] || '',
        template: this.selectedTemplate
      }

      if (targetGroup) {
        createParams.parentGroup = targetGroup
      }

      const customFields = new Map<string, string>()
      this.selectedTemplate.fields.forEach((f: FieldSpec) => {
        if (!['Title', 'UserName', 'Password', 'URL', 'Notes'].includes(f.key)) {
          if (this.formData[f.key]) {
            customFields.set(f.key, this.formData[f.key])
          }
        }
      })
      if (customFields.size > 0) {
        createParams.customFields = customFields
      }

      const createResult = this.kdbxEntryManager.createEntry(createParams)

      if (createResult.success && createResult.data) {

        await DatabaseFileService.saveDatabaseToFile(this.kdbxCore, this.databaseFileManager);

        const newEntryId = ((createResult.data.uuid as ESObject).id) as string

        await this.initializeSidebarItems()
        await this.loadEntriesForSidebar(this.selectedSidebarId || 'all_entries')

        const createdItem = this.entryItems.find(item => item.id === newEntryId)
        if (createdItem) {
          this.updateSelectedEntry(createdItem)
        }

        this.hideAddForm()

        console.log('MainPage', '条目创建成功')
        
        this.successToastMessage = '创建成功'
        this.showCopySuccessToast = true
        if (this.copySuccessTimer !== null) {
          clearTimeout(this.copySuccessTimer)
        }
        this.copySuccessTimer = setTimeout(() => {
          this.showCopySuccessToast = false
          this.copySuccessTimer = null
        }, 2500)
      } else {
        console.error('MainPage', '创建条目失败:', createResult.error)
        this.showValidationError('创建条目失败：' + (createResult.error || '未知错误'))
      }
    } catch (error) {
      console.error('MainPage', '提交表单时发生错误:', error)
    } finally {
      this.isSubmitting = false
    }
  }

  /**
   * 提交编辑表单
   */
  private async submitEditForm() {
    if (!this.kdbxEntryManager || !this.selectedEntry) {
      console.error('MainPage', '数据库管理器未初始化或未选择条目')
      return
    }

    const titleKey = this.selectedTemplate.fields.some(f => f.key === 'Title') ? 'Title' : this.selectedTemplate.fields[0]?.key
    const baseRequired: string[] = titleKey ? [titleKey] : []
    const extraRequired: string[] = ['UserName', 'Password']
    const requiredKeys: string[] = baseRequired.concat(
      extraRequired.filter(key => this.selectedTemplate.fields.some(f => f.key === key))
    )

    const missingKeys: string[] = requiredKeys.filter(key => !this.formData[key])

    if (missingKeys.length > 0) {
      const missingLabels = this.selectedTemplate.fields
        .filter(f => missingKeys.includes(f.key))
        .map(f => f.label || f.key)
        .join('、')

      this.showValidationError(`请填写必填字段：${missingLabels}`)
      return
    }

    this.isSubmitting = true

    try {
      const kdbxEntry: ESObject | null = await this.getKdbxEntryById(this.selectedEntry.id)
      if (!kdbxEntry) {
        console.error('MainPage', '未找到原始条目')
        return
      }

      const updateParams: EntryUpdateParams = {
        template: this.selectedTemplate
      }

      if (this.formData['Title'] !== undefined) updateParams.title = this.formData['Title']
      if (this.formData['UserName'] !== undefined) updateParams.username = this.formData['UserName']
      if (this.formData['Password'] !== undefined) updateParams.password = this.formData['Password']
      if (this.formData['URL'] !== undefined) updateParams.url = this.formData['URL']
      if (this.formData['Notes'] !== undefined) updateParams.notes = this.formData['Notes']

      const customFields = new Map<string, string>()
      this.selectedTemplate.fields.forEach((f: FieldSpec) => {
        if (!['Title', 'UserName', 'Password', 'URL', 'Notes'].includes(f.key)) {
          if (this.formData[f.key] !== undefined) {
            customFields.set(f.key, this.formData[f.key])
          }
        }
      })
      if (customFields.size > 0) {
        updateParams.customFields = customFields
      }

      const result = this.kdbxEntryManager.updateEntry(kdbxEntry as ESObject, updateParams)

      if (result.success) {

        await DatabaseFileService.saveDatabaseToFile(this.kdbxCore, this.databaseFileManager);

        await this.loadEntriesForSidebar(this.selectedSidebarId || 'all_entries')
        const updated = this.entryItems.find(item => item.id === this.selectedEntry?.id)
        if (updated) {
          this.updateSelectedEntry(updated)
        }

        this.hideEditForm()

        this.successToastMessage = '更新成功'
        this.showCopySuccessToast = true
        if (this.copySuccessTimer !== null) {
          clearTimeout(this.copySuccessTimer)
        }
        this.copySuccessTimer = setTimeout(() => {
          this.showCopySuccessToast = false
          this.copySuccessTimer = null
        }, 2500)
      } else {
        this.showValidationError('更新失败：' + (result.error || '未知错误'))
      }
    } catch (error) {
      console.error('MainPage', '提交编辑表单时发生错误:', error)
    } finally {
      this.isSubmitting = false
    }
  }


  build() {
    if (!this.isInitialized) {
      Column() {
        Text('正在初始化...')
          .fontSize(16)
          .fontColor('#666')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#f5f5f5')
    } else if (this.error) {
      Column() {
        Text(this.error)
          .fontSize(16)
          .fontColor('#ff4444')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 20 })

        Button('返回首页')
          .onClick(() => {
            this.onBackToHome()
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#f5f5f5')
    } else {
      Row() {
        if (!this.isFirstColumnCollapsed) {
          Column() {
            Row() {
              Image($r('app.media.right_arrow'))
                .width(16)
                .height(16)
                .fillColor('#666')
                .margin({ right: 8 })
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/KdbxPage'
                  }, router.RouterMode.Standard, (err) => {
                    if (err) {
                      console.error('MainPage', '跳转到KdbxPage失败:', err)
                    }
                  })
                })
              
              Text(this.databaseName)
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#000')
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/KdbxPage'
                  })
                })

              Image($r('app.media.lock'))
                .width(20)
                .height(20)
                .fillColor('#666')
                .onClick(() => {
                  this.onBackToHome()
                })
            }
            .width('100%')
            .height(50)
            .padding({ left: 16, right: 16 })
            .backgroundColor('#f8f9fa')
            .border({ width: { bottom: 1 }, color: '#e0e0e0' })

            Column() {
              Column() {
                ForEach(this.fixedSidebarItems, (item: SidebarItem) => {
                  Column() {
                    this.SidebarItemView(item)
                  }
                  .width('100%')
                  .onClick(() => {
                    if (item.type !== 'divider') {
                      this.onSidebarItemClick(item)
                    }
                  })
                }, (item: SidebarItem) => item.id)
              }
              .width('100%')
              .backgroundColor('#fff')
              
              List() {
                ForEach(this.scrollableSidebarItems, (item: SidebarItem) => {
                  ListItem() {
                    this.SidebarItemView(item)
                  }
                  .onClick(() => {
                    if (item.type !== 'divider') {
                      this.onSidebarItemClick(item)
                    }
                  })
                }, (item: SidebarItem) => item.id)
              }
              .width('100%')
              .layoutWeight(1)
              .backgroundColor('#fff')
            }
            .width('100%')
            .layoutWeight(1)
          }
          .width(this.firstColumnWidth)
          .height('100%')
          .backgroundColor('#f8f9fa')
          .transition(TransitionEffect.translate({ x: -this.firstColumnWidth }).animation({ duration: 300, curve: Curve.EaseInOut }))

          Divider()
            .vertical(true)
            .color('#e0e0e0')
            .strokeWidth(3)
            .gesture(
              PanGesture({ direction: PanDirection.Horizontal, fingers: 1 })
                .onActionStart(() => {
                  AutoCloseManager.getInstance().reset()
                })
                .onActionUpdate((event: GestureEvent) => {
                  let newFirstWidth = this.firstColumnWidth + event.offsetX
                  newFirstWidth = Math.max(200, Math.min(250, newFirstWidth))
                  this.firstColumnWidth = newFirstWidth
                })
                                 .onActionEnd(() => {
                   LayoutPreferencesUtil.saveFirstColumnWidth(this.firstColumnWidth)
                 })
            )
        }

        Column() {
          Row() {
            Image(this.isFirstColumnCollapsed ? $r('app.media.show') : $r('app.media.hide'))
              .width(20)
              .height(20)
              .margin({ right: 12 })
              .onClick(() => {
                this.onToggleFirstColumn()
              })

            Row() {
              TextInput({ placeholder: '搜索条目', text: this.searchState.query })
                .placeholderColor('#999')
                .fontSize(14)
                .border({ width: 1, color: '#ccc' })
                .borderRadius(4)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .layoutWeight(1)
                .onChange((value: string) => {
                  AutoCloseManager.getInstance().reset()
                  
                  if (this.kdbxQuery) {
                    this.searchHelper.debounceSearch(value, this.kdbxQuery, this.kdbxEntryManager ?? undefined)
                  }
                })

              if (this.searchState.query) {
                Button() {
                  Text('×')
                    .fontSize(16)
                    .fontColor('#666')
                }
                .backgroundColor('transparent')
                .padding(4)
                .margin({ left: 4 })
                .onClick(() => {
                  AutoCloseManager.getInstance().reset()
                  
                  this.searchHelper.clearSearch()
                })
              }
            }
            .layoutWeight(1)

            Button() {
              Image($r('app.media.new'))
                .width(20)
                .height(20)
                .fillColor(this.isInRecycleBin() || this.isAddingEntry || this.isEditingEntry ? '#999' : '#007AFF')
            }
            .backgroundColor('transparent')
            .padding(4)
            .stateEffect(false)
            .margin({ left: 8 })
            .enabled(!this.isInRecycleBin() && !this.isAddingEntry && !this.isEditingEntry)
            .onClick(() => {
              AutoCloseManager.getInstance().reset()
              
              this.showAddForm()
            })
          }
          .width('100%')
          .height(50)
          .padding({ left: 16, right: 8 })
          .backgroundColor('#f8f9fa')
          .border({ width: { bottom: 1 }, color: '#e0e0e0' })

          if (this.searchState.isSearching) {
            Row() {
              Text(`搜索结果：${this.searchState.results.length} 个条目`)
                .fontSize(12)
                .fontColor('#666')
                .margin({ left: 16 })
              
              Blank()
              
              Text(`关键词："${this.searchState.query}"`)
                .fontSize(12)
                .fontColor('#007AFF')
                .margin({ right: 16 })
            }
            .width('100%')
            .height(30)
            .backgroundColor('#f0f7ff')
            .alignItems(VerticalAlign.Center)
          }

          if (this.isLoading) {
            Column() {
              LoadingProgress()
                .width(40)
                .height(40)
                .color('#007AFF')
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .backgroundColor('#fff')
          } else if (EntryService.getCurrentDisplayEntries(this.searchState, this.entryItems).length === 0) {
            Column() {
              Image($r('app.media.startIcon'))
                .width(60)
                .height(60)
                .opacity(0.3)
                .margin({ bottom: 12 })

              Text(this.searchState.isSearching ? '未找到匹配的条目' : '暂无条目')
                .fontSize(16)
                .fontColor('#999')
                
              if (this.searchState.isSearching) {
                Text(`搜索"${this.searchState.query}"无结果`)
                  .fontSize(14)
                  .fontColor('#ccc')
                  .margin({ top: 8 })
              }
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .backgroundColor('#fff')
          } else {
            Scroll() {
              Column() {
                ForEach(EntryService.getCurrentDisplayEntries(this.searchState, this.entryItems), (entry: EntryItem) => {
                  Column() {
                    this.EntryItemView(entry)
                    
                    if (entry.id !== EntryService.getCurrentDisplayEntries(this.searchState, this.entryItems)[EntryService.getCurrentDisplayEntries(this.searchState, this.entryItems).length - 1]?.id) {
                      Divider()
                        .strokeWidth(0.8)
                        .color('#e0e0e0')
                        .margin({ left: 16, right: 0 })
                    }
                  }
                  .onHover((isHover: boolean) => {
                    this.hoverEntryId = isHover ? entry.id : (this.hoverEntryId === entry.id ? null : this.hoverEntryId)
                  })
                }, (entry: EntryItem) => entry.id)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .justifyContent(FlexAlign.Start)
            }
            .width('100%')
            .layoutWeight(1)
            .backgroundColor('#fff')
            .align(Alignment.TopStart)
          }
        }
        .width(this.secondColumnWidth)
        .height('100%')
        .backgroundColor('#fff')

        Divider()
          .vertical(true)
          .color('#e0e0e0')
          .strokeWidth(3)
          .gesture(
            PanGesture({ direction: PanDirection.Horizontal, fingers: 1 })
              .onActionStart(() => {
                AutoCloseManager.getInstance().reset()
              })
              .onActionUpdate((event: GestureEvent) => {
                let newSecondWidth = this.secondColumnWidth + event.offsetX
                newSecondWidth = Math.max(250, Math.min(350, newSecondWidth))
                this.secondColumnWidth = newSecondWidth
              })
                             .onActionEnd(() => {
                 LayoutPreferencesUtil.saveSecondColumnWidth(this.secondColumnWidth)
               })
          )

        Column() {
          this.DetailPanelView()
        }
        .layoutWeight(1)
        .height('100%')
        .backgroundColor('#fff')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#e5e5e5')
    }
  }

  /**
   * 自动关闭数据库
   */
  private async autoCloseDatabase(): Promise<void> {
    try {
      await DatabaseFileService.returnToIndex(this.kdbxCore, this.databaseFileManager)
    } catch (error) {
      console.error('MainPage', '自动关闭数据库失败:', error)
    }
  }

  /**
   * 页面即将消失时清理计时器
   */
  aboutToDisappear() {
    AutoCloseManager.getInstance().pause()
    this.searchHelper.destroy()
    
    if (this.copySuccessTimer !== null) {
      clearTimeout(this.copySuccessTimer)
      this.copySuccessTimer = null
    }
    
    if (this.validationErrorTimer !== null) {
      clearTimeout(this.validationErrorTimer)
      this.validationErrorTimer = null
    }
  }

  /**
   * 检查当前是否在回收站视图
   */
  private isInRecycleBin(): boolean {
    const selectedItem = this.sidebarItems.find(item => item.id === this.selectedSidebarId)
    return selectedItem?.type === 'recycle'
  }
} 

