import router from '@ohos.router'
import { KdbxCore, KdbxCoreManager } from '../utils/KdbxCore'
import { KdbxQuery } from '../utils/KdbxQuery'
import { KdbxEntryManager } from '../utils/KdbxEntryManager'
import { KdbxGroupManager } from '../utils/KdbxGroupManager'
// 移除对 kdbxweb 的依赖，使用内置类型兼容
import PreferencesUtil from '../utils/PreferencesUtil'
import { 
  LoginTemplate, SecureNoteTemplate, BankAccountTemplate, PaymentAccountTemplate,
  SecuritiesFundTemplate, EmailAccountTemplate, MembershipCardTemplate, SubscriptionTemplate,
  AddressBookTemplate, FamilyTemplate, CertificateTemplate, InsurancePolicyTemplate,
  UtilityAccountTemplate, MedicalRecordTemplate, LoyaltyProgramTemplate, KeyCertificateTemplate,
  ServerTemplate, DatabaseTemplate, IoTDeviceTemplate, VehicleInfoTemplate,
  RouterTemplate, ApiCredentialTemplate, SoftwareLicenseTemplate, CryptoWalletTemplate,
  OtherTemplate
} from '../templates/index'

// 侧边栏项目类型
interface SidebarItem {
  id: string
  title: string
  icon: Resource
  type: 'special' | 'group' | 'recycle' | 'divider'
  count?: number
  parentId?: string
}

// 字段信息类型
interface FieldInfo {
  label: string
  isProtected: boolean
}

// 渲染字段信息，在 UI 构建阶段只做纯渲染
interface RenderField {
  key: string
  label: string
  value: string
  type: 'password' | 'url' | 'text'
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
  groupName?: string  // 添加组名信息，用于获取模板
  fields?: Map<string, string>  // 存储所有字段的键值对
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
  @State private fixedSidebarItems: SidebarItem[] = []  // 固定在上方的项目
  @State private scrollableSidebarItems: SidebarItem[] = []  // 可滚动的项目
  @State private entryItems: EntryItem[] = []
  @State private selectedSidebarId: string | null = null
  @State private selectedEntryId: string | null = null
  @State private selectedEntry: EntryItem | null = null
  @State private passwordVisible: Set<string> = new Set()  // 记录哪些密码字段是可见的
  @State private sortedFields: string[] = []  // 排序后的字段键列表（保留备用）
  @State private renderFields: RenderField[] = [] // 供 UI 直接渲染的字段数据
  
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
    const allItems: SidebarItem[] = []
    const fixedItems: SidebarItem[] = []
    const scrollableItems: SidebarItem[] = []
    
    // 固定的特殊项目
    fixedItems.push({
      id: 'all_entries',
      title: '所有条目',
      icon: $r('app.media.startIcon'),
      type: 'special',
      count: await this.getTotalEntryCount()
    })
    
    fixedItems.push({
      id: 'starred',
      title: '加星条目',
      icon: $r('app.media.startIcon'),
      type: 'special',
      count: await this.getStarredEntryCount()
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
        for (const group of groupsResult.data) {
          const isRecycleBin = group.name === 'Recycle Bin'
          scrollableItems.push({
            id: group.uuid.id,
            title: isRecycleBin ? '回收站' : (group.name || '未命名'),
            icon: $r('app.media.startIcon'),
            type: isRecycleBin ? 'recycle' : 'group',
            count: await this.getGroupEntryCount(group.uuid.id)
          })
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
      
      let entries: Object[] = []
      
      // 检查是否是回收站
      const selectedItem = this.sidebarItems.find(item => item.id === sidebarId)
      const isRecycleBin = selectedItem?.type === 'recycle'
      
      if (sidebarId === 'all_entries') {
        const allResult = await this.kdbxQuery.getAllEntries()
        entries = allResult.success && allResult.data ? allResult.data : []
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
       const mappedItems: EntryItem[] = entries.map(entryRaw => {
         const entry: ESObject = entryRaw as ESObject;
         const entryFields = entry.fields as Map<string, Object>;
         
         // 提取所有字段
         const fields = new Map<string, string>();
         entryFields.forEach((value, key) => {
           const fieldValue = this.getFieldValue(entryFields, key);
           if (fieldValue && fieldValue.trim().length > 0) {
             fields.set(key, fieldValue);
           }
         });
         
         // 添加时间信息
         const lastModTime = ((entry.times as ESObject).lastModTime as Date) || new Date();
         fields.set('最后修改时间', this.formatDate(lastModTime));
         
         const creationTime = ((entry.times as ESObject).creationTime as Date);
         if (creationTime) {
           fields.set('创建时间', this.formatDate(creationTime));
         }
         
         return ({
           id: (entry.uuid as ESObject).id as string,
           title: this.getFieldValue(entryFields, 'Title') || '无标题',
           username: this.getFieldValue(entryFields, 'UserName') || '',
           notes: this.getFieldValue(entryFields, 'Notes') || '',
           url: this.getFieldValue(entryFields, 'URL') || '',
           icon: $r('app.media.startIcon'),
           lastModified: this.formatDate(lastModTime),
           groupId: entry.parentGroup ? ((entry.parentGroup as ESObject).uuid as ESObject).id as string : '',
           groupName: entry.parentGroup ? ((entry.parentGroup as ESObject).name as string) : '',
           fields: fields
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
   * 根据组名获取对应的模板
   */
  private getTemplateByGroupName(groupName: string) {
    // 导入所有模板
    const templates = [
      LoginTemplate, SecureNoteTemplate, BankAccountTemplate, PaymentAccountTemplate,
      SecuritiesFundTemplate, EmailAccountTemplate, MembershipCardTemplate, SubscriptionTemplate,
      AddressBookTemplate, FamilyTemplate, CertificateTemplate, InsurancePolicyTemplate,
      UtilityAccountTemplate, MedicalRecordTemplate, LoyaltyProgramTemplate, KeyCertificateTemplate,
      ServerTemplate, DatabaseTemplate, IoTDeviceTemplate, VehicleInfoTemplate,
      RouterTemplate, ApiCredentialTemplate, SoftwareLicenseTemplate, CryptoWalletTemplate,
      OtherTemplate
    ];
    
    return templates.find(template => template.name === groupName);
  }

  /**
   * 获取字段的显示信息（标签和是否敏感）
   */
  private getFieldInfo(fieldKey: string, groupName?: string): FieldInfo {
    // 特殊处理时间字段
    if (fieldKey === '最后修改时间' || fieldKey === '创建时间') {
      return { label: fieldKey, isProtected: false };
    }
    
    // 尝试从模板中获取字段信息
    if (groupName) {
      const template = this.getTemplateByGroupName(groupName);
      if (template) {
        const fieldSpec = template.fields.find(field => field.key === fieldKey);
        if (fieldSpec) {
          return { 
            label: fieldSpec.label, 
            isProtected: fieldSpec.protected === true 
          };
        }
      }
    }
    
    // 通用字段名称映射（用于用户自定义字段或未匹配的字段）
    const commonFieldNames: Record<string, string> = {
      'Title': '标题',
      'UserName': '用户名',
      'Password': '密码',
      'URL': '网址',
      'Notes': '备注'
    };
    
    // 通过关键词判断是否为敏感字段
    const sensitiveKeywords = ['password', 'pwd', 'key', 'secret', 'token', 'seed', 'private', 'cvv', 'pin'];
    const isProtected = sensitiveKeywords.some(keyword => 
      fieldKey.toLowerCase().includes(keyword.toLowerCase())
    );
    
    return {
      label: commonFieldNames[fieldKey] || fieldKey,
      isProtected
    };
  }

  /**
   * 处理字段排序逻辑
   */
  private processSortedFields() {
    if (!this.selectedEntry?.fields) {
      this.sortedFields = [];
      return;
    }

    // 获取所有有值的字段
    const allFields: string[] = [];
    this.selectedEntry.fields.forEach((value, key) => {
      if (value && value.trim().length > 0) {
        allFields.push(key);
      }
    });

    // 定义优先显示的字段顺序
    const priorityFields = [
      'Title', 'UserName', 'Password', 'URL', 'Email', 'Phone',
      'PayPassword', 'FundPassword', 'BankName', 'AccountNumber', 
      'CardNumber', 'ExpiryDate', 'CVV',
      'Host', 'Port', 'DBName', 'Protocol', 
      'Address', 'Seed', 'PrivateKey',
      'Company', 'Department', 'JobTitle', 'Website',
      'API_Key', 'SecretKey', 'AccessToken', 'RefreshToken',
      'License', 'SerialNumber', 'ActivationCode',
      'TOTP', 'Notes', '创建时间', '最后修改时间'
    ];

    // 按优先级排序字段
    this.sortedFields = allFields.sort((a, b) => {
      const aIndex = priorityFields.indexOf(a);
      const bIndex = priorityFields.indexOf(b);
      
      if (aIndex === -1 && bIndex === -1) return a.localeCompare(b);
      if (aIndex === -1) return 1;
      if (bIndex === -1) return -1;
      return aIndex - bIndex;
    });

    // 生成 renderFields 供 UI 渲染，避免在 build 方法里写逻辑
    const newRenderFields: RenderField[] = [];
    this.sortedFields.forEach(key => {
      const value = this.selectedEntry!.fields!.get(key) as string | undefined;
      if (!value || value.trim().length === 0) {
        return;
      }

      const fieldInfo: FieldInfo = this.getFieldInfo(key, this.selectedEntry!.groupName);
      let type: 'password' | 'url' | 'text' = 'text';
      if (fieldInfo.isProtected) {
        type = 'password';
      } else if (key === 'URL' || key === 'Website') {
        type = 'url';
      }

      newRenderFields.push({
        key,
        label: fieldInfo.label,
        value,
        type
      });
    });

    this.renderFields = newRenderFields;
  }

  /**
   * 侧边栏项目点击处理
   */
  private async onSidebarItemClick(item: SidebarItem) {
    // 分割线不可点击
    if (item.type === 'divider') {
      return
    }
    
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
    // 重置密码可见性状态
    this.passwordVisible = new Set()
    // 处理字段排序
    this.processSortedFields()
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
    if (item.type === 'divider') {
      // 分割线
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
            // 动态显示所有字段
            ForEach(this.renderFields, (field: RenderField) => {
              this.RenderFieldItem(field)
            }, (field: RenderField) => field.key)
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

        Button('复制')
          .fontSize(12)
          .backgroundColor('#f0f0f0')
          .fontColor('#007AFF')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .onClick(() => {
            // TODO: 实现复制功能
            console.log('复制内容:', value)
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Divider()
        .strokeWidth(1)
        .color('#f0f0f0')
        .margin({ top: 12, bottom: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 创建密码字段视图（带显示/隐藏功能）
   */
  @Builder
  private PasswordFieldView(label: string, value: string, fieldKey: string) {
    Column() {
      Row() {
        Text(label)
          .fontSize(14)
          .fontColor('#666')
          .fontWeight(FontWeight.Medium)
          .width(80)

        Text(this.passwordVisible.has(fieldKey) ? value : '••••••••')
          .fontSize(14)
          .fontColor('#000')
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
          .fontFamily('monospace')

        Button('复制')
          .fontSize(12)
          .backgroundColor('#f0f0f0')
          .fontColor('#007AFF')
          .padding({ left: 6, right: 6, top: 4, bottom: 4 })
          .margin({ right: 8 })
          .onClick(() => {
            // TODO: 实现复制功能
            console.log('复制密码:', value)
          })

        Button(this.passwordVisible.has(fieldKey) ? '隐藏' : '显示')
          .fontSize(12)
          .backgroundColor('#f0f0f0')
          .fontColor('#007AFF')
          .padding({ left: 6, right: 6, top: 4, bottom: 4 })
          .onClick(() => {
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
      .alignItems(VerticalAlign.Center)

      Divider()
        .strokeWidth(1)
        .color('#f0f0f0')
        .margin({ top: 12, bottom: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 创建URL字段视图（带点击跳转功能）
   */
  @Builder
  private URLFieldView(label: string, value: string) {
    Column() {
      Row() {
        Text(label)
          .fontSize(14)
          .fontColor('#666')
          .fontWeight(FontWeight.Medium)
          .width(80)

        Text(value)
          .fontSize(14)
          .fontColor('#007AFF')
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
          .decoration({ type: TextDecorationType.Underline })
          .onClick(() => {
            // TODO: 实现URL跳转功能
            console.log('点击链接:', value)
          })

        Button('复制')
          .fontSize(12)
          .backgroundColor('#f0f0f0')
          .fontColor('#007AFF')
          .padding({ left: 6, right: 6, top: 4, bottom: 4 })
          .margin({ right: 8 })
          .onClick(() => {
            // TODO: 实现复制功能
            console.log('复制链接:', value)
          })

        Button('打开')
          .fontSize(12)
          .backgroundColor('#f0f0f0')
          .fontColor('#007AFF')
          .padding({ left: 6, right: 6, top: 4, bottom: 4 })
          .onClick(() => {
            // TODO: 实现URL跳转功能
            console.log('打开链接:', value)
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Divider()
        .strokeWidth(1)
        .color('#f0f0f0')
        .margin({ top: 12, bottom: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 渲染单个字段，根据类型选择合适组件
   */
  @Builder
  private RenderFieldItem(field: RenderField) {
    if (field.type === 'password') {
      this.PasswordFieldView(field.label, field.value, field.key)
    } else if (field.type === 'url') {
      this.URLFieldView(field.label, field.value)
    } else {
      this.DetailFieldView(field.label, field.value)
    }
  }

  // 已移除 FieldItemView，所有逻辑在 processSortedFields 中完成，UI 只做渲染

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