import { KdbxEntryManager } from './KdbxEntryManager'
import { TemplateManager } from '../templates/TemplateManager'

/**
 * 条目项目类型
 */
export interface EntryItem {
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

/**
 * 条目转换器工具类
 * 负责将 KdbxEntry 转换为 EntryItem
 */
export class EntryConverter {
  
  /**
   * 将 KdbxEntry 转换为 EntryItem
   * @param entry KdbxEntry 对象
   * @param group 可选的组对象
   * @param kdbxEntryManager 条目管理器（用于判断是否加星）
   * @returns 转换后的 EntryItem 或 null
   */
  static convertKdbxEntryToEntryItem(entry: ESObject, group?: ESObject, kdbxEntryManager?: KdbxEntryManager): EntryItem | null {
    try {
      const entryFields = entry.fields as Map<string, Object>;
      
      // 提取所有字段
      const fields = new Map<string, string>();
      entryFields.forEach((value, key) => {
        const fieldValue = EntryConverter.getFieldValue(entryFields, key);
        if (fieldValue && fieldValue.trim().length > 0) {
          fields.set(key, fieldValue);
        }
      });
      
      // 添加时间信息
      const lastModTime = ((entry.times as ESObject).lastModTime as Date) || new Date();
      fields.set('修改时间', EntryConverter.formatDate(lastModTime));
      
      const creationTime = ((entry.times as ESObject).creationTime as Date);
      if (creationTime) {
        fields.set('创建时间', EntryConverter.formatDate(creationTime));
      }
      
      // 检查是否已加星
      const isStarred = kdbxEntryManager ? kdbxEntryManager.isEntryStarred(entry as ESObject) : false;
      fields.set('Starred', isStarred ? 'true' : 'false');
      
      // 提取tags信息
      const tags = (entry.tags as string[]) || [];
      if (tags.length > 0) {
        fields.set('Tags', tags.join(','));
      }
      
      // 获取组名
      const groupName = group ? ((group as ESObject).name as string) : (entry.parentGroup ? ((entry.parentGroup as ESObject).name as string) : '');
      
      return ({
        id: (entry.uuid as ESObject).id as string,
        title: EntryConverter.getFieldValue(entryFields, 'Title') || '无标题',
        username: EntryConverter.getFieldValue(entryFields, 'UserName') || '',
        notes: EntryConverter.getFieldValue(entryFields, 'Notes') || '',
        url: EntryConverter.getFieldValue(entryFields, 'URL') || '',
        icon: EntryConverter.getTemplateIcon(groupName), // 根据模板分类获取图标
        lastModified: EntryConverter.formatDate(lastModTime),
        groupId: group ? ((group as ESObject).uuid as ESObject).id as string : (entry.parentGroup ? ((entry.parentGroup as ESObject).uuid as ESObject).id as string : ''),
        groupName: groupName,
        fields: fields
      }) as EntryItem;
    } catch (error) {
      console.error('EntryConverter', '转换条目失败:', error)
      return null
    }
  }

  /**
   * 获取字段值（处理ProtectedValue）
   * @param fields 字段映射
   * @param key 字段键
   * @returns 字段值
   */
  private static getFieldValue(fields: Map<string, Object>, key: string): string {
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
   * @param date 日期对象
   * @returns 格式化后的日期字符串
   */
  private static formatDate(date: Date): string {
    return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`
  }

  /**
   * 根据模板分类名获取对应的图标
   * @param groupName 组名
   * @returns 图标资源
   */
  static getTemplateIcon(groupName: string): Resource {
    if (!groupName) {
      return $r('app.media.Templates_Default')
    }
    
    // 使用TemplateManager获取模板信息
    const template = TemplateManager.getTemplateByGroupName(groupName)
    if (!template) {
      // 用户自己创建的GROUP使用default.png
      return $r('app.media.Templates_Default')
    }
    
    // 获取英文名称映射
    const englishNameMapping = TemplateManager.getEnglishNameMapping()
    let englishName = ''
    
    // 查找对应的英文名称
    const entries = Object.entries(englishNameMapping)
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i]
      const key = entry[0]
      const value = entry[1]
      if (value === template.name) {
        englishName = key
        break
      }
    }
    
    // 如果找不到英文名称，使用模板名称
    if (!englishName) {
      englishName = template.name
    }
    
    // 根据英文名称返回对应的图标资源
    switch (englishName) {
      case 'Login':
        return $r('app.media.Templates_Login')
      case 'SecureNote':
        return $r('app.media.Templates_SecureNote')
      case 'BankAccount':
        return $r('app.media.Templates_BankAccount')
      case 'PaymentAccount':
        return $r('app.media.Templates_PaymentAccount')
      case 'SecuritiesFund':
        return $r('app.media.Templates_SecuritiesFund')
      case 'EmailAccount':
        return $r('app.media.Templates_EmailAccount')
      case 'MembershipCard':
        return $r('app.media.Templates_MembershipCard')
      case 'Subscription':
        return $r('app.media.Templates_Subscription')
      case 'AddressBook':
        return $r('app.media.Templates_AddressBook')
      case 'Family':
        return $r('app.media.Templates_Family')
      case 'Certificate':
        return $r('app.media.Templates_Certificate')
      case 'InsurancePolicy':
        return $r('app.media.Templates_InsurancePolicy')
      case 'UtilityAccount':
        return $r('app.media.Templates_UtilityAccount')
      case 'MedicalRecord':
        return $r('app.media.Templates_MedicalRecord')
      case 'LoyaltyProgram':
        return $r('app.media.Templates_LoyaltyProgram')
      case 'KeyCertificate':
        return $r('app.media.Templates_KeyCertificate')
      case 'Server':
        return $r('app.media.Templates_Server')
      case 'Database':
        return $r('app.media.Templates_Database')
      case 'IoTDevice':
        return $r('app.media.Templates_IoTDevice')
      case 'VehicleInfo':
        return $r('app.media.Templates_VehicleInfo')
      case 'Router':
        return $r('app.media.Templates_Router')
      case 'ApiCredential':
        return $r('app.media.Templates_ApiCredential')
      case 'SoftwareLicense':
        return $r('app.media.Templates_SoftwareLicense')
      case 'CryptoWallet':
        return $r('app.media.Templates_CryptoWallet')
      case 'Other':
        return $r('app.media.Templates_Other')
      default:
        return $r('app.media.Templates_Default')
    }
  }
} 