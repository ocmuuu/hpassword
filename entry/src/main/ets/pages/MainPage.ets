import router from '@ohos.router'
import { KdbxCore, KdbxCoreManager } from '../utils/KdbxCore'
import { KdbxQuery } from '../utils/KdbxQuery'
import { KdbxEntryManager } from '../utils/KdbxEntryManager'
import { KdbxGroupManager } from '../utils/KdbxGroupManager'
import { DatabaseFileManager } from '../utils/DatabaseFileManager'
import { OperationResult, SearchCriteria } from '../utils/KdbxTypes'
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
  @State private databaseFileManager: DatabaseFileManager | null = null
  
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
  @State private updateCounter: number = 0 // 强制更新计数器
  @State private hoverEntryId: string | null = null  // 鼠标悬停的条目ID
  @State private hoverFieldKey: string | null = null  // 详情面板悬停字段Key
  @State private searchQuery: string = ''  // 条目搜索关键字
  @State private filteredEntryItems: EntryItem[] = []  // 搜索过滤后的条目列表
  @State private isSearching: boolean = false  // 是否正在搜索状态
  
  // 布局状态
  @State private isFirstColumnCollapsed: boolean = false
  @State private firstColumnWidth: number = 250
  @State private secondColumnWidth: number = 350
  @State private isInitialized: boolean = false
  
  // 加载状态
  @State private isLoading: boolean = false
  @State private error: string | null = null
  
  // 自动超时相关
  private autoCloseTimer: number | null = null
  private readonly AUTO_CLOSE_TIMEOUT = 600000  // 10分钟自动关闭
  
  // 搜索防抖相关
  private searchTimer: number | null = null
  private readonly SEARCH_DEBOUNCE_DELAY = 300  // 搜索防抖延迟300ms

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
          
          // 初始化文件管理器
          const context = getContext(this) as Context
          this.databaseFileManager = new DatabaseFileManager(context)
        }
        
        // 初始化数据
        await this.initializeData()
      } else {
        this.error = '数据库实例获取失败'
      }
      
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
        const systemTemplateNames = [
          LoginTemplate.name, SecureNoteTemplate.name, BankAccountTemplate.name, PaymentAccountTemplate.name,
          SecuritiesFundTemplate.name, EmailAccountTemplate.name, MembershipCardTemplate.name, SubscriptionTemplate.name,
          AddressBookTemplate.name, FamilyTemplate.name, CertificateTemplate.name, InsurancePolicyTemplate.name,
          UtilityAccountTemplate.name, MedicalRecordTemplate.name, LoyaltyProgramTemplate.name, KeyCertificateTemplate.name,
          ServerTemplate.name, DatabaseTemplate.name, IoTDeviceTemplate.name, VehicleInfoTemplate.name,
          RouterTemplate.name, ApiCredentialTemplate.name, SoftwareLicenseTemplate.name, CryptoWalletTemplate.name,
          OtherTemplate.name
        ]
        
        // 先处理非回收站分组
        let recycleBinGroup: SidebarItem | null = null
        
        for (const group of groupsResult.data) {
          const isRecycleBin = group.name === 'Recycle Bin'
          const groupName = group.name || '未命名'
          const entryCount = await this.getGroupEntryCount(group.uuid.id)
          
          if (isRecycleBin) {
            // 暂存回收站分组，稍后添加到最后
            recycleBinGroup = {
              id: group.uuid.id,
              title: '回收站',
              icon: $r('app.media.trash'),
              type: 'recycle',
              count: entryCount
            } as SidebarItem
            continue
          }
          
          // 判断是否为系统模板分组
          const isSystemTemplate = systemTemplateNames.includes(groupName)
          
          // 过滤逻辑：
          // 1. 非系统模板分组始终显示
          // 2. 系统模板分组只有在有条目时才显示
          if (!isSystemTemplate || entryCount > 0) {
            scrollableItems.push({
              id: group.uuid.id,
              title: groupName,
              icon: $r('app.media.startIcon'),
              type: 'group',
              count: entryCount
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
       const mappedItems: EntryItem[] = entries.map((entryRaw: ESObject) => {
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
         fields.set('修改时间', this.formatDate(lastModTime));
         
         const creationTime = ((entry.times as ESObject).creationTime as Date);
         if (creationTime) {
           fields.set('创建时间', this.formatDate(creationTime));
         }
         
         // 检查是否已加星
         const isStarred = this.kdbxEntryManager ? this.kdbxEntryManager.isEntryStarred(entry as ESObject) : false;
         fields.set('Starred', isStarred ? 'true' : 'false');
         
         // 提取tags信息
         const tags = (entry.tags as string[]) || [];
         if (tags.length > 0) {
           fields.set('Tags', tags.join(','));
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
    // 创建全新的数组，确保触发响应式更新
    this.renderFields = [];
    
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

    // 立即设置新的 renderFields
    this.renderFields = newRenderFields;
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
    this.clearSearch()
    
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
      if (this.isSearching) {
        this.clearSearch()
        
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
      Image(entry.icon)
        .width(20)
        .height(20)
        .margin({ right: 12 })
        .fillColor('#666666')

      Column() {
        Text(entry.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.containsSearchKeyword(entry.title) ? '#007AFF' : '#000')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)

        if (entry.username) {
          Text(entry.username)
            .fontSize(14)
            .fontColor(this.containsSearchKeyword(entry.username) ? '#007AFF' : '#666')
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
    if (this.selectedEntry) {
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
                  
                  // 更新侧边栏的加星数量
                  await this.updateSidebarStarredCount();
                  
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
            
            // TODO: 实现编辑功能
          })

          // 删除按钮
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
            
            // 删除条目：移动至回收站
            if (!this.selectedEntry || !this.kdbxEntryManager) {
              return
            }

            // 获取原始 KdbxEntry
            const kdbxEntry: ESObject | null = await this.getKdbxEntryById(this.selectedEntry.id)
            if (!kdbxEntry) {
              return
            }

            // 调用管理器删除（软删除会移动到回收站）
            const delResult = this.kdbxEntryManager.deleteEntry(kdbxEntry as ESObject)
            if (delResult.success) {
              // 保存数据库
              await this.saveDatabaseToFile()

              // 重新构建侧边栏数据（更新计数）
              await this.initializeSidebarItems()

              // 刷新当前列表（若当前视图不是回收站，条目会消失）
              await this.loadEntriesForSidebar(this.selectedSidebarId || 'all_entries')

              // 清空详情选择
              this.selectedEntry = null
              this.selectedEntryId = null
            }
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
      .padding({ top: 60 })
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Start)
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
          .borderRadius(3)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .opacity(this.hoverFieldKey === label ? 1 : 0)
          .onClick(() => {
            // 重置自动关闭计时器
            this.resetAutoCloseTimer()
            
            // TODO: 实现复制功能
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
          .borderRadius(3)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .opacity(this.hoverFieldKey === fieldKey ? 1 : 0)
          .onClick(() => {
            // 重置自动关闭计时器
            this.resetAutoCloseTimer()
            
            // TODO: 实现复制功能
          })

        Button(this.passwordVisible.has(fieldKey) ? '隐藏' : '显示')
          .fontSize(12)
          .backgroundColor('#f0f0f0')
          .fontColor('#007AFF')
          .padding({ left: 6, right: 6, top: 4, bottom: 4 })
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
            // 重置自动关闭计时器
            this.resetAutoCloseTimer()
            
            // TODO: 实现URL跳转功能
          })

        Button('复制')
          .fontSize(12)
          .backgroundColor('#f0f0f0')
          .fontColor('#007AFF')
          .borderRadius(3)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .opacity(this.hoverFieldKey === label ? 1 : 0)
          .onClick(() => {
            // 重置自动关闭计时器
            this.resetAutoCloseTimer()
            
            // TODO: 实现复制功能
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
        .margin({ top: 8, bottom: 8 })
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
   * 更新侧边栏加星条目的数量
   */
  private async updateSidebarStarredCount(): Promise<void> {
    try {
      const newStarredCount = await this.getStarredEntryCount();
      
      // 直接重新构建侧边栏数据，确保 UI 计数立即刷新
      await this.initializeSidebarItems();
      
    } catch (error) {
      console.error('MainPage', '更新加星数量失败:', error);
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
              Text('密码库')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#000')
                .layoutWeight(1)

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
              TextInput({ placeholder: '搜索条目', text: this.searchQuery })
                .placeholderColor('#999')
                .fontSize(14)
                .border({ width: 1, color: '#ccc' })
                .borderRadius(4)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .layoutWeight(1)
                .onChange((value: string) => {
                  // 重置自动关闭计时器
                  this.resetAutoCloseTimer()
                  
                  this.searchQuery = value
                  // 执行防抖搜索
                  this.debounceSearch(value)
                })

              // 清空搜索按钮
              if (this.searchQuery) {
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
                  
                  this.clearSearch()
                })
              }
            }
            .layoutWeight(1)

            // 新增按钮
            Button() {
              Image($r('app.media.new'))
                .width(20)
                .height(20)
                .fillColor('#007AFF')
            }
            .backgroundColor('transparent')
            .padding(4)
            .stateEffect(false)
            .margin({ left: 8 })
            .onClick(() => {
              // 重置自动关闭计时器
              this.resetAutoCloseTimer()
              
              // TODO: 实现新增条目功能
            })
          }
          .width('100%')
          .height(50)
          .padding({ left: 16, right: 8 })
          .backgroundColor('#f8f9fa')
          .border({ width: { bottom: 1 }, color: '#e0e0e0' })

          // 搜索结果统计
          if (this.isSearching) {
            Row() {
              Text(`搜索结果：${this.filteredEntryItems.length} 个条目`)
                .fontSize(12)
                .fontColor('#666')
                .margin({ left: 16 })
              
              Blank()
              
              Text(`关键词："${this.searchQuery}"`)
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

              Text(this.isSearching ? '未找到匹配的条目' : '暂无条目')
                .fontSize(16)
                .fontColor('#999')
                
              if (this.isSearching) {
                Text(`搜索"${this.searchQuery}"无结果`)
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
                        .strokeWidth(0.5)
                        .color('#f0f0f0')
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
    this.clearSearchTimer()
  }

  /**
   * 清除搜索计时器
   */
  private clearSearchTimer() {
    if (this.searchTimer !== null) {
      clearTimeout(this.searchTimer)
      this.searchTimer = null
    }
  }

  /**
   * 防抖搜索
   */
  private debounceSearch(query: string) {
    // 清除之前的计时器
    this.clearSearchTimer()
    
    // 设置新的计时器
    this.searchTimer = setTimeout(() => {
      this.performSearch(query)
    }, this.SEARCH_DEBOUNCE_DELAY)
  }

  /**
   * 执行搜索
   */
  private async performSearch(query: string) {
    if (!this.kdbxQuery) {
      return
    }

    try {
      if (!query.trim()) {
        // 空搜索，显示当前选中侧边栏的所有条目
        this.isSearching = false
        this.filteredEntryItems = []
        return
      }

      this.isSearching = true

      // 构建搜索条件
      const searchCriteria: SearchCriteria = {
        query: query.trim(),
        searchInTitles: true,
        searchInUsernames: true,
        searchInUrls: true,
        searchInNotes: true,
        caseSensitive: false,
        useRegex: false
      }

      // 执行搜索
      const searchResult = this.kdbxQuery.searchEntries(searchCriteria)
      
      if (searchResult.success && searchResult.data) {
        // 将搜索结果转换为 EntryItem 格式
        const searchedItems: EntryItem[] = []
        
        for (const result of searchResult.data) {
          const entryItem = this.convertKdbxEntryToEntryItem(result.entry, result.group)
          if (entryItem) {
            searchedItems.push(entryItem)
          }
        }

        this.filteredEntryItems = searchedItems
      } else {
        this.filteredEntryItems = []
      }

    } catch (error) {
      console.error('MainPage', '搜索失败:', error)
      this.filteredEntryItems = []
    }
  }

  /**
   * 将 KdbxEntry 转换为 EntryItem
   */
  private convertKdbxEntryToEntryItem(entry: ESObject, group?: ESObject): EntryItem | null {
    try {
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
      fields.set('修改时间', this.formatDate(lastModTime));
      
      const creationTime = ((entry.times as ESObject).creationTime as Date);
      if (creationTime) {
        fields.set('创建时间', this.formatDate(creationTime));
      }
      
      // 检查是否已加星
      const isStarred = this.kdbxEntryManager ? this.kdbxEntryManager.isEntryStarred(entry as ESObject) : false;
      fields.set('Starred', isStarred ? 'true' : 'false');
      
      // 提取tags信息
      const tags = (entry.tags as string[]) || [];
      if (tags.length > 0) {
        fields.set('Tags', tags.join(','));
      }
      
      return ({
        id: (entry.uuid as ESObject).id as string,
        title: this.getFieldValue(entryFields, 'Title') || '无标题',
        username: this.getFieldValue(entryFields, 'UserName') || '',
        notes: this.getFieldValue(entryFields, 'Notes') || '',
        url: this.getFieldValue(entryFields, 'URL') || '',
        icon: $r('app.media.startIcon'),
        lastModified: this.formatDate(lastModTime),
        groupId: group ? ((group as ESObject).uuid as ESObject).id as string : (entry.parentGroup ? ((entry.parentGroup as ESObject).uuid as ESObject).id as string : ''),
        groupName: group ? ((group as ESObject).name as string) : (entry.parentGroup ? ((entry.parentGroup as ESObject).name as string) : ''),
        fields: fields
      }) as EntryItem;
    } catch (error) {
      console.error('MainPage', '转换条目失败:', error)
      return null
    }
  }

  /**
   * 获取当前显示的条目列表（搜索时显示搜索结果，否则显示侧边栏选中的条目）
   */
  private getCurrentDisplayEntries(): EntryItem[] {
    if (this.isSearching) {
      return this.filteredEntryItems
    }
    return this.entryItems
  }

  /**
   * 清空搜索
   */
  private clearSearch() {
    this.searchQuery = ''
    this.isSearching = false
    this.filteredEntryItems = []
  }

  /**
   * 检查文本是否包含搜索关键词（用于高亮显示）
   */
  private containsSearchKeyword(text: string): boolean {
    if (!this.isSearching || !this.searchQuery.trim()) {
      return false
    }
    return text.toLowerCase().includes(this.searchQuery.toLowerCase())
  }
} 