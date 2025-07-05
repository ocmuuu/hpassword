import router from '@ohos.router'
import { KdbxCore, KdbxCoreManager } from '../utils/KdbxCore'
import { KdbxQuery } from '../utils/KdbxQuery'
import { KdbxEntryManager } from '../utils/KdbxEntryManager'
import { KdbxGroupManager } from '../utils/KdbxGroupManager'
// 移除对 kdbxweb 的依赖，使用内置类型兼容
import PreferencesUtil from '../utils/PreferencesUtil'

// 侧边栏项目类型
interface SidebarItem {
  id: string
  title: string
  icon: Resource
  type: 'special' | 'group' | 'recycle'
  count?: number
  parentId?: string
}

// 条目项目类型
interface EntryItem {
  id: string
  title: string
  username: string
  notes: string
  url: string
  icon: Resource
  lastModified: string
  groupId?: string
}

@Entry
@Component
struct MainPage {
  @State private kdbxCore: KdbxCore | null = null
  @State private kdbxQuery: KdbxQuery | null = null
  @State private kdbxEntryManager: KdbxEntryManager | null = null
  @State private kdbxGroupManager: KdbxGroupManager | null = null
  
  // 数据状态
  @State private sidebarItems: SidebarItem[] = []
  @State private entryItems: EntryItem[] = []
  @State private selectedSidebarId: string | null = null
  @State private selectedEntryId: string | null = null
  @State private selectedEntry: EntryItem | null = null
  
  // 布局状态
  @State private isFirstColumnCollapsed: boolean = false
  @State private firstColumnWidth: number = 250
  @State private secondColumnWidth: number = 350
  @State private isInitialized: boolean = false
  
  // 加载状态
  @State private isLoading: boolean = false
  @State private error: string | null = null

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
        }
        
        // 初始化数据
        await this.initializeData()
      } else {
        this.error = '数据库实例获取失败'
      }
      
      this.isInitialized = true
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
      
      if (savedFirstWidth >= 200 && savedFirstWidth <= 300) {
        this.firstColumnWidth = savedFirstWidth
      }
      if (savedSecondWidth >= 300 && savedSecondWidth <= 450) {
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
    const items: SidebarItem[] = []
    
    // 特殊项目
    items.push({
      id: 'all_entries',
      title: '所有条目',
      icon: $r('app.media.startIcon'),
      type: 'special',
      count: await this.getTotalEntryCount()
    })
    
    items.push({
      id: 'starred',
      title: '加星条目',
      icon: $r('app.media.startIcon'),
      type: 'special',
      count: await this.getStarredEntryCount()
    })
    
    items.push({
      id: 'recently_modified',
      title: '最近修改',
      icon: $r('app.media.startIcon'),
      type: 'special',
      count: await this.getRecentlyModifiedCount()
    })
    
         // 组项目
     if (this.kdbxQuery) {
       const groupsResult = await this.kdbxQuery.getAllGroups()
       if (groupsResult.success && groupsResult.data) {
         for (const group of groupsResult.data) {
           items.push({
             id: group.uuid.id,
             title: (group.name || '未命名'),
             icon: $r('app.media.startIcon'),
             type: 'group',
             count: await this.getGroupEntryCount(group.uuid.id)
           })
         }
       }
     }
    
    // 回收站
    items.push({
      id: 'recycle_bin',
      title: '回收站',
      icon: $r('app.media.startIcon'),
      type: 'recycle',
      count: await this.getRecycleBinCount()
    })
    
    this.sidebarItems = items
  }

  /**
   * 为侧边栏项目加载条目
   */
  private async loadEntriesForSidebar(sidebarId: string) {
    try {
      if (!this.kdbxQuery) {
        return
      }
      
             let entries: Object[] = []
       
       switch (sidebarId) {
         case 'all_entries':
           const allResult = await this.kdbxQuery.getAllEntries()
           entries = allResult.success && allResult.data ? allResult.data : []
           break
         case 'starred':
           const starredResult = await this.kdbxQuery.getStarredEntries()
           entries = starredResult.success && starredResult.data ? starredResult.data : []
           break
         case 'recently_modified':
           const recentResult = await this.kdbxQuery.getRecentlyModifiedEntries()
           entries = recentResult.success && recentResult.data ? recentResult.data : []
           break
         case 'recycle_bin':
           const recycleResult = await this.kdbxQuery.getRecycleBinEntries()
           entries = recycleResult.success && recycleResult.data ? recycleResult.data : []
           break
         default:
           // 组条目
           const groupResult = await this.kdbxQuery.getEntriesByGroup(sidebarId)
           entries = groupResult.success && groupResult.data ? groupResult.data : []
           break
       }
      
             // 转换为UI显示格式
       const mappedItems: EntryItem[] = entries.map(entryRaw => {
         const entry: ESObject = entryRaw as ESObject;
         return ({
           id: (entry.uuid as ESObject).id as string,
           title: this.getFieldValue((entry.fields as Map<string, Object>), 'Title') || '无标题',
           username: this.getFieldValue((entry.fields as Map<string, Object>), 'UserName') || '',
           notes: this.getFieldValue((entry.fields as Map<string, Object>), 'Notes') || '',
           url: this.getFieldValue((entry.fields as Map<string, Object>), 'URL') || '',
           icon: $r('app.media.startIcon'),
           lastModified: this.formatDate(((entry.times as ESObject).lastModTime as Date) || new Date()),
           groupId: entry.parentGroup ? ((entry.parentGroup as ESObject).uuid as ESObject).id as string : ''
         }) as EntryItem;
       })
       this.entryItems = mappedItems
      
    } catch (error) {
      console.error('MainPage', '加载条目失败:', error)
    }
  }

  /**
   * 获取统计数据的辅助方法
   */
  private async getTotalEntryCount(): Promise<number> {
    if (!this.kdbxQuery) return 0
    const result = await this.kdbxQuery.getAllEntries()
    return result.success && result.data ? result.data.length : 0
  }

  private async getStarredEntryCount(): Promise<number> {
    if (!this.kdbxQuery) return 0
    const result = await this.kdbxQuery.getStarredEntries()
    return result.success && result.data ? result.data.length : 0
  }

  private async getRecentlyModifiedCount(): Promise<number> {
    if (!this.kdbxQuery) return 0
    const result = await this.kdbxQuery.getRecentlyModifiedEntries()
    return result.success && result.data ? result.data.length : 0
  }

  private async getGroupEntryCount(groupId: string): Promise<number> {
    if (!this.kdbxQuery) return 0
    const result = await this.kdbxQuery.getEntriesByGroup(groupId)
    return result.success && result.data ? result.data.length : 0
  }

  private async getRecycleBinCount(): Promise<number> {
    if (!this.kdbxQuery) return 0
    const result = await this.kdbxQuery.getRecycleBinEntries()
    return result.success && result.data ? result.data.length : 0
  }

  /**
   * 获取字段值（处理ProtectedValue）
   */
  private getFieldValue(fields: Map<string, Object>, key: string): string {
    const rawValue = fields.get(key)
    if (!rawValue) {
      return ''
    }

    // 尝试读取受保护值
    if (typeof rawValue === 'object' && (rawValue as ESObject).getText) {
      return (rawValue as ESObject).getText() as string
    }

    return rawValue.toString()
  }

  /**
   * 格式化日期
   */
  private formatDate(date: Date): string {
    return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`
  }

  /**
   * 侧边栏项目点击处理
   */
  private async onSidebarItemClick(item: SidebarItem) {
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
    this.selectedEntryId = entry.id
    this.selectedEntry = entry
  }

  /**
   * 切换第一栏折叠状态
   */
  private onToggleFirstColumn() {
    this.isFirstColumnCollapsed = !this.isFirstColumnCollapsed
    
         // 保存状态
     if (PreferencesUtil.isInitialized()) {
       PreferencesUtil.saveKdbxFirstColumnCollapseStateSync(this.isFirstColumnCollapsed)
     }
  }

  /**
   * 返回首页
   */
  private onBackToHome() {
    router.back()
  }

  /**
   * 创建侧边栏项目视图
   */
  @Builder
  private SidebarItemView(item: SidebarItem) {
    Row() {
      Image(item.icon)
        .width(20)
        .height(20)
        .margin({ right: 12 })
        .fillColor(item.type === 'special' ? '#007AFF' : '#666666')

      Text(item.title)
        .fontSize(16)
        .fontWeight(item.type === 'special' ? FontWeight.Medium : FontWeight.Normal)
        .fontColor('#000')
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (item.count !== undefined && item.count > 0) {
        Text(item.count.toString())
          .fontSize(12)
          .fontColor('#fff')
          .backgroundColor('#007AFF')
          .borderRadius(10)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      }
    }
    .width('100%')
    .height(40)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.selectedSidebarId === item.id ? '#f0f7ff' : '#fff')
    .alignItems(VerticalAlign.Center)
  }

  /**
   * 创建条目项目视图
   */
  @Builder
  private EntryItemView(entry: EntryItem) {
    Column() {
      Row() {
        Image(entry.icon)
          .width(20)
          .height(20)
          .margin({ right: 12 })
          .fillColor('#666666')

        Column() {
          Text(entry.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#000')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Start)

          if (entry.username) {
            Text(entry.username)
              .fontSize(14)
              .fontColor('#666')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .textAlign(TextAlign.Start)
              .margin({ top: 2 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (entry.url) {
        Text(entry.url)
          .fontSize(12)
          .fontColor('#999')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
          .margin({ top: 4 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.selectedEntryId === entry.id ? '#f0f7ff' : '#fff')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 创建详情面板视图
   */
  @Builder
  private DetailPanelView() {
    if (this.selectedEntry) {
      Column() {
        // 标题栏
        Row() {
          Text(this.selectedEntry.title)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000')
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Button('编辑')
            .fontSize(14)
            .backgroundColor('#007AFF')
            .onClick(() => {
              // TODO: 实现编辑功能
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 16 })
        .backgroundColor('#f8f9fa')
        .border({ width: { bottom: 1 }, color: '#e0e0e0' })

        // 详情内容
        Scroll() {
          Column() {
            // 用户名
            if (this.selectedEntry.username) {
              this.DetailFieldView('用户名', this.selectedEntry.username)
            }

            // 网址
            if (this.selectedEntry.url) {
              this.DetailFieldView('网址', this.selectedEntry.url)
            }

            // 备注
            if (this.selectedEntry.notes) {
              this.DetailFieldView('备注', this.selectedEntry.notes)
            }

            // 最后修改时间
            this.DetailFieldView('最后修改', this.selectedEntry.lastModified)
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 16 })
        }
        .layoutWeight(1)
        .backgroundColor('#fff')
      }
      .width('100%')
      .height('100%')
    } else {
      // 空状态
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
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
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
          .fontSize(14)
          .fontColor('#666')
          .fontWeight(FontWeight.Medium)
          .width(80)

        Text(value)
          .fontSize(14)
          .fontColor('#000')
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Divider()
        .strokeWidth(1)
        .color('#f0f0f0')
        .margin({ top: 12, bottom: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
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
              Text('密码库')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#000')
                .layoutWeight(1)

              Button('返回')
                .fontSize(14)
                .backgroundColor('#f0f0f0')
                .fontColor('#666')
                .onClick(() => {
                  this.onBackToHome()
                })
            }
            .width('100%')
            .height(50)
            .padding({ left: 16, right: 16 })
            .backgroundColor('#f8f9fa')
            .border({ width: { bottom: 1 }, color: '#e0e0e0' })

            // 侧边栏列表
            List() {
              ForEach(this.sidebarItems, (item: SidebarItem) => {
                ListItem() {
                  this.SidebarItemView(item)
                }
                .onClick(() => {
                  this.onSidebarItemClick(item)
                })
              }, (item: SidebarItem) => item.id)
            }
            .width('100%')
            .layoutWeight(1)
            .backgroundColor('#fff')
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
                .onActionUpdate((event: GestureEvent) => {
                  let newFirstWidth = this.firstColumnWidth + event.offsetX
                  newFirstWidth = Math.max(200, Math.min(300, newFirstWidth))
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
          // 条目列表标题
          Row() {
            // 折叠/展开按钮
            Image(this.isFirstColumnCollapsed ? $r('app.media.show') : $r('app.media.hide'))
              .width(20)
              .height(20)
              .margin({ right: 12 })
              .onClick(() => {
                this.onToggleFirstColumn()
              })

            Text(this.selectedSidebarId ? 
              (this.sidebarItems.find(item => item.id === this.selectedSidebarId)?.title || '条目列表') : 
              '条目列表')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor('#000')
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(`${this.entryItems.length} 项`)
              .fontSize(14)
              .fontColor('#666')
          }
          .width('100%')
          .height(50)
          .padding({ left: 16, right: 16 })
          .backgroundColor('#f8f9fa')
          .border({ width: { bottom: 1 }, color: '#e0e0e0' })

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
          } else if (this.entryItems.length === 0) {
            Column() {
              Image($r('app.media.startIcon'))
                .width(60)
                .height(60)
                .opacity(0.3)
                .margin({ bottom: 12 })

              Text('暂无条目')
                .fontSize(16)
                .fontColor('#999')
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .backgroundColor('#fff')
          } else {
            List() {
              ForEach(this.entryItems, (entry: EntryItem) => {
                ListItem() {
                  this.EntryItemView(entry)
                }
                .onClick(() => {
                  this.onEntryItemClick(entry)
                })
              }, (entry: EntryItem) => entry.id)
            }
            .width('100%')
            .layoutWeight(1)
            .backgroundColor('#fff')
            .divider({ strokeWidth: 0.5, color: '#f0f0f0', startMargin: 16, endMargin: 0 })
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
              .onActionUpdate((event: GestureEvent) => {
                let newSecondWidth = this.secondColumnWidth + event.offsetX
                newSecondWidth = Math.max(300, Math.min(450, newSecondWidth))
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
} 