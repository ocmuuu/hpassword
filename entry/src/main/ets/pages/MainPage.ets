import router from '@ohos.router'
import pasteboard from '@ohos.pasteboard'
import { KdbxCore, KdbxCoreManager } from '../utils/KdbxCore'
import { KdbxQuery } from '../utils/KdbxQuery'
import { KdbxEntryManager } from '../utils/KdbxEntryManager'
import { KdbxGroupManager } from '../utils/KdbxGroupManager'
import { DatabaseFileManager } from '../utils/DatabaseFileManager'
import { OperationResult, EntryCreateParams, EntryUpdateParams } from '../utils/KdbxTypes'
import PreferencesUtil from '../utils/PreferencesUtil'
import { TemplateManager, CategoryTemplate } from '../templates/index'
import { EntryConverter, EntryItem } from '../utils/EntryConverter'
import { FieldInfoHelper, FieldInfo, RenderField } from '../templates/FieldInfoHelper'
import { SearchHelper, SearchState } from '../utils/SearchHelper'
import { LoginTemplate } from '../templates/Login'
import { FieldSpec } from '../templates/TemplateTypes'

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
  
  // 自动超时相关
  private autoCloseTimer: number | null = null
  private readonly AUTO_CLOSE_TIMEOUT = 600000  // 10分钟自动关闭
  
  // 复制成功提醒定时器
  private copySuccessTimer: number | null = null
  
  // 表单验证错误提醒定时器
  private validationErrorTimer: number | null = null

  async aboutToAppear() {
    try {
      // 获取应用上下文并初始化首选项
      const context = getContext(this) as Context
      
      // 尝试使用同步方法初始化
      let initialized = PreferencesUtil.initSync(context)
      if (!initialized) {
        initialized = await PreferencesUtil.init(context)
      }
      
      if (initialized) {
        // 恢复布局状态
        await this.restoreLayoutStates()
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
          
          // 获取数据库名称
          if (db.meta && db.meta.name) {
            this.databaseName = db.meta.name
          }
          
          // 初始化文件管理器
          const context = getContext(this) as Context
          this.databaseFileManager = new DatabaseFileManager(context)
        }
        
        // 初始化数据
        await this.initializeData()
      } else {
        this.error = '数据库实例获取失败'
      }
      
      // 设置搜索助手的回调
      this.searchHelper.setCallback((state: SearchState) => {
        this.searchState = state
      })
      
      this.isInitialized = true
      
      // 启动自动关闭计时器
      this.startAutoCloseTimer()
    } catch (error) {
      this.error = `初始化失败: ${error}`
      this.isInitialized = true
    }
  }

  /**
   * 恢复布局状态
   */
  private async restoreLayoutStates() {
    try {
      if (!PreferencesUtil.isInitialized()) {
        return
      }

      // 恢复第一栏折叠状态
      this.isFirstColumnCollapsed = PreferencesUtil.getKdbxFirstColumnCollapseStateSync()
      
      // 恢复列宽度
      const savedFirstWidth = PreferencesUtil.getKdbxFirstColumnWidthSync()
      const savedSecondWidth = PreferencesUtil.getKdbxSecondColumnWidthSync()
      
      if (savedFirstWidth >= 200 && savedFirstWidth <= 250) {
        this.firstColumnWidth = savedFirstWidth
      }
      if (savedSecondWidth >= 250 && savedSecondWidth <= 350) {
        this.secondColumnWidth = savedSecondWidth
      }
      
    } catch (error) {
      console.error('MainPage', '恢复布局状态失败:', error)
    }
  }

  /**
   * 初始化数据
   */
  private async initializeData() {
    try {
      this.isLoading = true
      
      // 初始化侧边栏数据
      await this.initializeSidebarItems()
      
      // 默认选中"所有条目"
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
    const allItems: SidebarItem[] = []
    const fixedItems: SidebarItem[] = []
    const scrollableItems: SidebarItem[] = []
    
    // 固定的特殊项目
    fixedItems.push({
      id: 'starred',
      title: '加星',
      icon: $r('app.media.star'),
      type: 'special'
    })
    
    fixedItems.push({
      id: 'all_entries',
      title: '所有条目',
      icon: $r('app.media.all'),
      type: 'special'
    })
    
    // 添加分割线到固定区域
    fixedItems.push({
      id: 'divider_fixed',
      title: '',
      icon: $r('app.media.startIcon'),
      type: 'divider'
    })
    
    // 组项目（可滚动）
    if (this.kdbxQuery) {
      const groupsResult = await this.kdbxQuery.getAllGroups()
      if (groupsResult.success && groupsResult.data) {
        // 获取所有系统模板分组名称
        const systemTemplateNames = TemplateManager.getSystemTemplateNames()
        
        // 先处理非回收站分组
        let recycleBinGroup: SidebarItem | null = null
        
        for (const group of groupsResult.data) {
          const isRecycleBin = group.name === 'Recycle Bin'
          const groupName = group.name || '未命名'
          
          if (isRecycleBin) {
            // 暂存回收站分组，稍后添加到最后
            recycleBinGroup = {
              id: group.uuid.id,
              title: '回收站',
              icon: $r('app.media.trash'),
              type: 'recycle'
            } as SidebarItem
            continue
          }
          
          // 判断是否为系统模板分组
          const isSystemTemplate = systemTemplateNames.includes(groupName)
          
          // 过滤逻辑：
          // 1. 非系统模板分组始终显示
          // 2. 系统模板分组只有在有条目时才显示
          let shouldShow = true
          if (isSystemTemplate) {
            // 检查该分组是否有条目
            const groupResult = await this.kdbxQuery.getEntriesByGroup(group.uuid.id)
            const hasEntries = !!(groupResult.success && groupResult.data && groupResult.data.length > 0)
            shouldShow = hasEntries
          }
          
          if (shouldShow) {
            scrollableItems.push({
              id: group.uuid.id,
              title: groupName,
              icon: EntryConverter.getTemplateIcon(groupName), // 根据模板分类获取图标
              type: 'group'
            })
          }
        }
        
        // 回收站始终显示在最后
        if (recycleBinGroup) {
          scrollableItems.push(recycleBinGroup)
        }
      }
    }
    
    // 注意：回收站会作为普通组由 getAllGroups() 返回，不需要手动添加
    
    // 合并所有项目（保持向后兼容）
    allItems.push(...fixedItems, ...scrollableItems)
    
    this.sidebarItems = allItems
    this.fixedSidebarItems = fixedItems
    this.scrollableSidebarItems = scrollableItems
  }

  /**
   * 为侧边栏项目加载条目
   */
  private async loadEntriesForSidebar(sidebarId: string) {
    try {
      if (!this.kdbxQuery) {
        return
      }
      
      let entries: ESObject[] = []
      
      // 检查是否是回收站
      const selectedItem = this.sidebarItems.find(item => item.id === sidebarId)
      const isRecycleBin = selectedItem?.type === 'recycle'
      
      if (sidebarId === 'all_entries') {
        const allResult = await this.kdbxQuery.getAllEntries()
        if (allResult.success && allResult.data) {
          // 排除回收站的条目
          entries = allResult.data.filter((entry: ESObject): boolean => {
            const parentGroup: ESObject | null = entry.parentGroup as ESObject | null
            return parentGroup !== null && (parentGroup.name as string) !== 'Recycle Bin'
          })
        } else {
          entries = []
        }
      } else if (sidebarId === 'starred') {
        const starredResult = await this.kdbxQuery.getStarredEntries()
        entries = starredResult.success && starredResult.data ? starredResult.data : []
      } else if (isRecycleBin) {
        const recycleResult = await this.kdbxQuery.getRecycleBinEntries()
        entries = recycleResult.success && recycleResult.data ? recycleResult.data : []
      } else {
        // 普通组条目
        const groupResult = await this.kdbxQuery.getEntriesByGroup(sidebarId)
        entries = groupResult.success && groupResult.data ? groupResult.data : []
      }
      
             // 转换为UI显示格式
       const mappedItems: EntryItem[] = entries.map((entryRaw: ESObject) => {
         const entry: ESObject = entryRaw as ESObject;
         const entryItem = EntryConverter.convertKdbxEntryToEntryItem(entry, undefined, this.kdbxEntryManager ?? undefined);
         return entryItem;
       }).filter(item => item !== null) as EntryItem[];
       this.entryItems = mappedItems
      
    } catch (error) {
      console.error('MainPage', '加载条目失败:', error)
    }
  }

  /**
   * 处理字段排序逻辑
   */
  private processSortedFields() {
    if (!this.selectedEntry?.fields) {
      this.sortedFields = [];
      this.renderFields = [];
      return;
    }

    // 使用 FieldInfoHelper 进行字段处理
    this.renderFields = FieldInfoHelper.processSortedFields(
      this.selectedEntry.fields,
      this.selectedEntry.groupName
    );

    // 为了保持兼容性，更新 sortedFields（UI 可能仍然需要这个数组）
    this.sortedFields = this.renderFields.map(field => field.key);
  }

  /**
   * 侧边栏项目点击处理
   */
  private async onSidebarItemClick(item: SidebarItem) {
    // 重置自动关闭计时器
    this.resetAutoCloseTimer()
    
    // 分割线不可点击
    if (item.type === 'divider') {
      return
    }
    
    // 清空搜索状态
    this.searchHelper.clearSearch()
    
    this.selectedSidebarId = item.id
    this.selectedEntryId = null
    this.selectedEntry = null
    
    // 加载对应的条目列表
    await this.loadEntriesForSidebar(item.id)
    
         // 保存选中状态
     if (PreferencesUtil.isInitialized()) {
       PreferencesUtil.saveSelectedKdbxSidebarIdSync(item.id)
     }
  }

  /**
   * 条目项目点击处理
   */
  private onEntryItemClick(entry: EntryItem) {
    try {
      // 重置自动关闭计时器
      this.resetAutoCloseTimer()
      
      // 使用通用方法安全地更新选中条目
      this.updateSelectedEntry(entry)
      
      // 如果当前在搜索状态，清除搜索
      if (this.searchState.isSearching) {
        this.searchHelper.clearSearch()
        
        // 如果条目有分组信息，异步切换到对应的分组
        if (entry.groupId && entry.groupId !== this.selectedSidebarId) {
          this.selectedSidebarId = entry.groupId
          // 异步加载分组条目，不等待完成
          this.loadEntriesForSidebar(entry.groupId).then(() => {
            // 重新从加载的条目中找到对应的条目（确保数据一致性）
            const updatedEntry = this.entryItems.find(item => item.id === entry.id)
            if (updatedEntry) {
              // 使用通用方法安全地更新选中条目
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
  private updateSelectedEntry(entry: EntryItem) {
    // 递增更新计数器，强制触发响应式更新
    this.updateCounter++
    
    // 先完全清空状态，触发UI重新渲染
    this.selectedEntry = null
    this.renderFields = []
    this.passwordVisible = new Set()
    
    // 使用 nextTick 确保状态变化被检测到
    setTimeout(() => {
      // 创建新的条目对象，确保所有嵌套对象都是全新的
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
      
      // 立即处理字段排序
      this.processSortedFields()
    }, 1)
  }

  /**
   * 强制UI刷新的辅助方法
   */
  private forceUIRefresh() {
    // 通过触发状态变化强制UI重新渲染
    const temp = this.selectedEntry
    this.selectedEntry = null
    setTimeout(() => {
      this.selectedEntry = temp
    }, 1)
  }

  /**
   * 切换第一栏折叠状态
   */
  private onToggleFirstColumn() {
    // 重置自动关闭计时器
    this.resetAutoCloseTimer()
    
    this.isFirstColumnCollapsed = !this.isFirstColumnCollapsed
    
         // 保存状态
     if (PreferencesUtil.isInitialized()) {
       PreferencesUtil.saveKdbxFirstColumnCollapseStateSync(this.isFirstColumnCollapsed)
     }
  }

  /**
   * 返回首页：保存并关闭数据库，跳转到 Index 页面并重置密码输入
   */
  private async returnToIndex() {
    try {
      // 先尝试保存数据库（忽略保存失败不阻止返回）
      await this.saveDatabaseToFile();
    } catch (error) {
      console.error('MainPage', '返回时保存数据库失败:', error);
    }

    // 清理当前数据库实例
    KdbxCoreManager.getInstance().clearCurrentKdbxCore();

    // 使用 replaceUrl 跳转并替换当前页面，避免保留旧页面状态
    router.replaceUrl({
      url: 'pages/Index'
    });
  }

  /**
   * 返回首页：保存并关闭数据库，跳转到 Index 页面并重置密码输入
   */
  private async onBackToHome() {
    // 清除自动关闭计时器（用户主动返回）
    this.clearAutoCloseTimer()
    
    await this.returnToIndex()
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
      // 在回收站时不显示图标
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
                  // 标题栏
          Row() {
            Text(this.selectedEntry.title + (this.updateCounter > 0 ? '' : ''))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000')
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

          // 根据当前视图显示不同的按钮
          if (!this.isInRecycleBin()) {
            // 非回收站视图：显示加星、编辑、删除按钮
            
            // 加星/取消加星按钮
            Button() {
              Image(this.isEntryStarred(this.selectedEntry) ? $r('app.media.star') : $r('app.media.unstar'))
                .width(20)
                .height(20)
                .fillColor(this.isEntryStarred(this.selectedEntry) ? '#FFD700' : '#666')
            }
            .backgroundColor('transparent')
            .padding(4)
            .margin({ right: 4 })
            .stateEffect(false)
            .onClick(async () => {
              // 重置自动关闭计时器
              this.resetAutoCloseTimer()
              
              if (this.selectedEntry && this.kdbxEntryManager) {
                const kdbxEntry: ESObject | null = await this.getKdbxEntryById(this.selectedEntry.id);
                if (kdbxEntry) {
                  const result = this.kdbxEntryManager.toggleEntryStarred(kdbxEntry);
                  if (result.success) {
                    // 保存数据库到文件
                    await this.saveDatabaseToFile();
                    
                    // 刷新列表
                    await this.loadEntriesForSidebar(this.selectedSidebarId || 'all_entries');
                    // 更新选中项
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
              // 重置自动关闭计时器
              this.resetAutoCloseTimer()
              
              // 显示编辑表单
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
            // 重置自动关闭计时器
            this.resetAutoCloseTimer()
            
            if (!this.selectedEntry || !this.kdbxEntryManager) {
              return
            }

            // 获取原始 KdbxEntry
            const kdbxEntry: ESObject | null = await this.getKdbxEntryById(this.selectedEntry.id)
            if (!kdbxEntry) {
              return
            }

            const delResult = this.kdbxEntryManager.deleteEntry(kdbxEntry as ESObject)
            
            if (delResult.success) {
              await this.saveDatabaseToFile()

              // 重新构建侧边栏数据（更新计数）
              await this.initializeSidebarItems()

              // 刷新当前列表
              await this.loadEntriesForSidebar(this.selectedSidebarId || 'all_entries')

              // 清空详情选择
              this.selectedEntry = null
              this.selectedEntryId = null
              console.log('MainPage', 'UI更新完成')
            } else {
              console.error('MainPage', '删除失败:', delResult.error)
            }
          })

          // Help 信息按钮
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

        // 详情内容
        Scroll() {
          Column() {
            // 动态显示所有字段
            ForEach(this.renderFields, (field: RenderField) => {
              this.RenderFieldItem(field)
            }, (field: RenderField) => field.key + '_' + this.updateCounter)

            // 占位符，撑满剩余空间，确保内容靠顶部显示
            Blank()
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 16 })
          .justifyContent(FlexAlign.Start)
        }
        .layoutWeight(1)
        .backgroundColor('#fff')
        
        // 复制成功提醒
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
      // 顶部栏：显示数据库管理和帮助按钮
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
        
        // 复制成功提醒
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
            // 重置自动关闭计时器
            this.resetAutoCloseTimer()
            
            // 复制文本到剪贴板
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
      this.resetAutoCloseTimer();
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
            // 重置自动关闭计时器
            this.resetAutoCloseTimer()
            
            // 复制文本到剪贴板
            this.copyToClipboard(value)
          })

        Button(this.passwordVisible.has(fieldKey) ? '隐藏' : '显示')
          .fontSize(12)
          .backgroundColor('#f0f0f0')
          .fontColor('#000')
          .padding({ left: 6, right: 6, top: 4, bottom: 4 })
          .opacity(this.hoverFieldKey === fieldKey ? 1 : 0)
          .onClick(() => {
            // 重置自动关闭计时器
            this.resetAutoCloseTimer()
            
            if (this.passwordVisible.has(fieldKey)) {
              this.passwordVisible.delete(fieldKey);
            } else {
              this.passwordVisible.add(fieldKey);
            }
            // 触发状态更新
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
      this.resetAutoCloseTimer();
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
      // 标题栏
      Row() {
        Text(`${this.isEditingEntry ? '编辑' : '新建'}${this.selectedTemplate.name}条目`)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#000')
          .layoutWeight(1)

        // 取消按钮
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

      // 表单内容
      Scroll() {
        Column() {
          // 模板选择区域
          Column() {
            Row() {

              // 模板选择区域（编辑模式下仅展示，不可点击）
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

          // 分割线
          Divider()
            .strokeWidth(1)
            .color('#e0e0e0')
            .margin({ top: 4, bottom: 16 })

          // 根据模板动态生成表单字段
          ForEach(this.selectedTemplate.fields, (field: FieldSpec) => {
            Column() {
              // 字段标签
              Row() {
                Text(field.label)
                  .fontSize(16)
                  .fontColor('#333')
                  .fontWeight(FontWeight.Medium)
                  .margin({ bottom: 8 })

                // 必填标记
                if (field.key === 'Title' || field.key === 'UserName' || field.key === 'Password') {
                  Text('*')
                    .fontSize(16)
                    .fontColor('#ff4444')
                    .margin({ left: 4 })
                }
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              // 输入框
              if (field.key === 'Notes') {
                // 备注使用多行输入
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
                // 其他字段使用单行输入
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

          // 占位符，撑满剩余空间
          Blank()
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 16 })
        .justifyContent(FlexAlign.Start)
      }
      .layoutWeight(1)
      .backgroundColor('#fff')
      
      // 验证错误提醒
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
   * 判断条目是否已加星
   */
  private isEntryStarred(entry: EntryItem | null): boolean {
    if (!entry) return false;
    
    // 从fields中查找star相关标记
    const fields = entry.fields;
    if (!fields) return false;
    
    // 检查是否有star字段
    if (fields.get('Starred') === 'true') {
      return true;
    }
    
    // 检查标签（如果有的话）
    const tags = fields.get('Tags') || '';
    if (tags.toLowerCase().includes('star') || tags.toLowerCase().includes('favorite')) {
      return true;
    }
    
    return false;
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
   * 保存数据库到文件
   */
  private async saveDatabaseToFile(): Promise<void> {
    try {
      if (!this.kdbxCore || !this.databaseFileManager) {
        console.error('MainPage', '数据库核心或文件管理器未初始化');
        return;
      }

      const database = this.kdbxCore.getDatabase();
      if (!database) {
        console.error('MainPage', '数据库实例不存在');
        return;
      }

      const saveResult = await this.databaseFileManager.saveDatabaseToFile(database, 'default.kdbx');
      if (!saveResult.success) {
        console.error('MainPage', '数据库保存失败:', saveResult.error);
      }
    } catch (error) {
      console.error('MainPage', '保存数据库时发生错误:', error);
    }
  }

  /**
   * 复制文本到剪贴板
   */
  private async copyToClipboard(text: string): Promise<void> {
    try {
      const pasteboardData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
      const systemPasteboard = pasteboard.getSystemPasteboard()
      await systemPasteboard.setData(pasteboardData)
      console.log('MainPage', '复制成功:', text.substring(0, 20) + (text.length > 20 ? '...' : ''))
      
      // 清除之前的定时器
      if (this.copySuccessTimer !== null) {
        clearTimeout(this.copySuccessTimer)
        this.copySuccessTimer = null
      }
      
      // 显示复制成功提醒
      this.successToastMessage = '复制成功'
      this.showCopySuccessToast = true
      
      // 2.5秒后自动隐藏提醒
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
    // 在添加模式时关闭编辑模式
    this.isEditingEntry = false
    this.isAddingEntry = true
    this.selectedEntry = null
    this.selectedEntryId = null

    // 根据当前侧边栏选中组，动态选择模板
    let templateToUse: CategoryTemplate = LoginTemplate
    const sidebarItem = this.sidebarItems.find(item => item.id === this.selectedSidebarId)
    if (sidebarItem && sidebarItem.type === 'group') {
      const matched = TemplateManager.getTemplateByGroupName(sidebarItem.title)
      if (matched) {
        templateToUse = matched
      }
    }
    // 如果不是系统模板组，则保持登录密码模板
    this.selectedTemplate = templateToUse

    // 初始化表单数据
    this.formData = {}
    this.selectedTemplate.fields.forEach((field: FieldSpec) => {
      this.formData[field.key] = ''
    })

    // 回收站中禁用新建
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
    // 清除验证错误定时器
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

    // 根据组名匹配模板
    const tpl: CategoryTemplate | null = TemplateManager.getTemplateByGroupName(this.selectedEntry.groupName || '') ?? null
    this.selectedTemplate = tpl ? tpl : LoginTemplate

    // 初始化表单数据为当前条目值
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
    // 清除之前的定时器
    if (this.validationErrorTimer !== null) {
      clearTimeout(this.validationErrorTimer)
      this.validationErrorTimer = null
    }
    
    // 显示错误提醒
    this.validationError = message
    
    // 3秒后自动隐藏提醒
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

    // 根据当前模板动态验证必填字段
    // 基础必填字段：若模板包含 Title 则用 Title，否则取第一个字段
    const titleKey = this.selectedTemplate.fields.some(f => f.key === 'Title') ? 'Title' : this.selectedTemplate.fields[0]?.key
    const baseRequired: string[] = titleKey ? [titleKey] : []
    const extraRequired: string[] = ['UserName', 'Password']
    const requiredKeys: string[] = baseRequired.concat(
      extraRequired.filter(key => this.selectedTemplate.fields.some(f => f.key === key))
    )

    const missingKeys: string[] = requiredKeys.filter(key => !this.formData[key])

    if (missingKeys.length > 0) {
      // 获取缺失字段对应的中文标签
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
      // 1. 优先根据模板名称匹配系统模板分组
      let targetGroup: ESObject | undefined = undefined
      const allGroupsResult = await this.kdbxQuery?.getAllGroups()
      if (allGroupsResult?.success && allGroupsResult.data) {
        targetGroup = allGroupsResult.data.find((g: ESObject) => (g.name as string) === this.selectedTemplate.name)
      }

      // 2. 若未找到模板对应组，则按侧边栏选中项或默认逻辑
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

      // 生成标题：若模板无 Title 字段，则使用首字段内容
      const titleValue: string = this.formData[titleKey] || ''

      const createParams: EntryCreateParams = {
        title: titleValue,
        username: this.formData['UserName'],
        password: this.formData['Password'],
        url: this.formData['URL'] || '',
        notes: this.formData['Notes'] || '',
        template: this.selectedTemplate
      }
      // 设置 parentGroup
      if (targetGroup) {
        createParams.parentGroup = targetGroup
      }

      // 添加自定义字段
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

      // 创建新条目
      const createResult = this.kdbxEntryManager.createEntry(createParams)

      if (createResult.success && createResult.data) {

        // 保存到文件
        await this.saveDatabaseToFile()

        // 新建条目 ID
        const newEntryId = ((createResult.data.uuid as ESObject).id) as string

        // 刷新界面
        await this.initializeSidebarItems()
        await this.loadEntriesForSidebar(this.selectedSidebarId || 'all_entries')

        // 定位并选中新建的条目
        const createdItem = this.entryItems.find(item => item.id === newEntryId)
        if (createdItem) {
          this.updateSelectedEntry(createdItem)
        }

        // 隐藏表单
        this.hideAddForm()

        console.log('MainPage', '条目创建成功')
        
        // 显示成功提醒
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

    // 验证必填字段（与新增逻辑一致）
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

      // 自定义字段
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
        // 保存
        await this.saveDatabaseToFile()

        // 刷新列表和详情
        await this.loadEntriesForSidebar(this.selectedSidebarId || 'all_entries')
        const updated = this.entryItems.find(item => item.id === this.selectedEntry?.id)
        if (updated) {
          this.updateSelectedEntry(updated)
        }

        // 隐藏表单
        this.hideEditForm()

        // 成功提示
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
      // 加载状态
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
      // 错误状态
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
      // 主界面
      Row() {
        // 第一栏：侧边栏
        if (!this.isFirstColumnCollapsed) {
          Column() {
            // 侧边栏标题
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

            // 侧边栏内容
            Column() {
              // 固定区域：所有条目、加星条目、分割线
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
              
              // 可滚动区域：分类组和回收站
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

          // 分割线
          Divider()
            .vertical(true)
            .color('#e0e0e0')
            .strokeWidth(3)
            .gesture(
              PanGesture({ direction: PanDirection.Horizontal, fingers: 1 })
                .onActionStart(() => {
                  // 重置自动关闭计时器
                  this.resetAutoCloseTimer()
                })
                .onActionUpdate((event: GestureEvent) => {
                  let newFirstWidth = this.firstColumnWidth + event.offsetX
                  newFirstWidth = Math.max(200, Math.min(250, newFirstWidth))
                  this.firstColumnWidth = newFirstWidth
                })
                                 .onActionEnd(() => {
                   if (PreferencesUtil.isInitialized()) {
                     PreferencesUtil.saveKdbxFirstColumnWidthSync(this.firstColumnWidth)
                   }
                 })
            )
        }

        // 第二栏：条目列表
        Column() {
          // 条目列表顶部工具栏
          Row() {
            // 折叠/展开按钮
            Image(this.isFirstColumnCollapsed ? $r('app.media.show') : $r('app.media.hide'))
              .width(20)
              .height(20)
              .margin({ right: 12 })
              .onClick(() => {
                this.onToggleFirstColumn()
              })

            // 搜索框容器
            Row() {
              TextInput({ placeholder: '搜索条目', text: this.searchState.query })
                .placeholderColor('#999')
                .fontSize(14)
                .border({ width: 1, color: '#ccc' })
                .borderRadius(4)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .layoutWeight(1)
                .onChange((value: string) => {
                  // 重置自动关闭计时器
                  this.resetAutoCloseTimer()
                  
                  // 使用搜索助手进行防抖搜索
                  if (this.kdbxQuery) {
                    this.searchHelper.debounceSearch(value, this.kdbxQuery, this.kdbxEntryManager ?? undefined)
                  }
                })

              // 清空搜索按钮
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
                  // 重置自动关闭计时器
                  this.resetAutoCloseTimer()
                  
                  this.searchHelper.clearSearch()
                })
              }
            }
            .layoutWeight(1)

            // 新增按钮
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
              // 重置自动关闭计时器
              this.resetAutoCloseTimer()
              
              // 显示添加表单
              this.showAddForm()
            })
          }
          .width('100%')
          .height(50)
          .padding({ left: 16, right: 8 })
          .backgroundColor('#f8f9fa')
          .border({ width: { bottom: 1 }, color: '#e0e0e0' })

          // 搜索结果统计
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

          // 条目列表
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
          } else if (this.getCurrentDisplayEntries().length === 0) {
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
                ForEach(this.getCurrentDisplayEntries(), (entry: EntryItem) => {
                  Column() {
                    this.EntryItemView(entry)
                    
                    // 分割线
                    if (entry.id !== this.getCurrentDisplayEntries()[this.getCurrentDisplayEntries().length - 1]?.id) {
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

        // 分割线
        Divider()
          .vertical(true)
          .color('#e0e0e0')
          .strokeWidth(3)
          .gesture(
            PanGesture({ direction: PanDirection.Horizontal, fingers: 1 })
              .onActionStart(() => {
                // 重置自动关闭计时器
                this.resetAutoCloseTimer()
              })
              .onActionUpdate((event: GestureEvent) => {
                let newSecondWidth = this.secondColumnWidth + event.offsetX
                newSecondWidth = Math.max(250, Math.min(350, newSecondWidth))
                this.secondColumnWidth = newSecondWidth
              })
                             .onActionEnd(() => {
                 if (PreferencesUtil.isInitialized()) {
                   PreferencesUtil.saveKdbxSecondColumnWidthSync(this.secondColumnWidth)
                 }
               })
          )

        // 第三栏：详情面板
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
   * 启动自动关闭计时器
   */
  private startAutoCloseTimer() {
    // 清除已有计时器
    this.clearAutoCloseTimer()
    
    // 启动新计时器
    this.autoCloseTimer = setTimeout(() => {
      this.autoCloseDatabase()
    }, this.AUTO_CLOSE_TIMEOUT)
  }

  /**
   * 重置自动关闭计时器
   */
  private resetAutoCloseTimer() {
    this.startAutoCloseTimer()
  }

  /**
   * 清除自动关闭计时器
   */
  private clearAutoCloseTimer() {
    if (this.autoCloseTimer !== null) {
      clearTimeout(this.autoCloseTimer)
      this.autoCloseTimer = null
    }
  }

  /**
   * 自动关闭数据库
   */
  private async autoCloseDatabase() {
    try {
      // 执行与返回按钮相同的逻辑
      await this.returnToIndex()
    } catch (error) {
      console.error('MainPage', '自动关闭数据库失败:', error)
    }
  }

  /**
   * 页面即将消失时清理计时器
   */
  aboutToDisappear() {
    this.clearAutoCloseTimer()
    this.searchHelper.destroy()
    
    // 清理复制成功提醒定时器
    if (this.copySuccessTimer !== null) {
      clearTimeout(this.copySuccessTimer)
      this.copySuccessTimer = null
    }
    
    // 清理验证错误提醒定时器
    if (this.validationErrorTimer !== null) {
      clearTimeout(this.validationErrorTimer)
      this.validationErrorTimer = null
    }
  }

  /**
   * 获取当前显示的条目列表（搜索时显示搜索结果，否则显示侧边栏选中的条目）
   */
  private getCurrentDisplayEntries(): EntryItem[] {
    if (this.searchState.isSearching) {
      return this.searchState.results
    }
    return this.entryItems
  }

  /**
   * 检查当前是否在回收站视图
   */
  private isInRecycleBin(): boolean {
    const selectedItem = this.sidebarItems.find(item => item.id === this.selectedSidebarId)
    return selectedItem?.type === 'recycle'
  }
} 

