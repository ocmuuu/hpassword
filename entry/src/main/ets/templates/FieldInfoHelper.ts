import { TemplateManager } from './TemplateManager'

/**
 * 字段信息类型
 */
export interface FieldInfo {
  label: string
  isProtected: boolean
}

/**
 * 渲染字段信息，在 UI 构建阶段只做纯渲染
 */
export interface RenderField {
  key: string
  label: string
  value: string
  type: 'password' | 'url' | 'text'
}

/**
 * 字段信息处理工具类
 * 负责字段显示信息获取、排序等逻辑
 */
export class FieldInfoHelper {
  
  /**
   * 获取字段的显示信息（标签和是否敏感）
   * @param fieldKey 字段键
   * @param groupName 可选的组名
   * @returns 字段信息
   */
  static getFieldInfo(fieldKey: string, groupName?: string): FieldInfo {
    // 特殊处理时间字段
    if (fieldKey === '修改时间' || fieldKey === '创建时间') {
      return { label: fieldKey, isProtected: false };
    }
    
    // 尝试从模板中获取字段信息
    if (groupName) {
      const template = TemplateManager.getTemplateByGroupName(groupName);
      if (template) {
        // 先尝试精确匹配
        let fieldSpec = template.fields.find(field => field.key === fieldKey);
        
        // 如果精确匹配失败，尝试大小写不敏感匹配
        if (!fieldSpec) {
          fieldSpec = template.fields.find(field => 
            field.key.toLowerCase() === fieldKey.toLowerCase()
          );
        }
        
        if (fieldSpec) {
          return { 
            label: fieldSpec.label, 
            isProtected: fieldSpec.protected === true 
          };
        }
      }
    }
    
    // 通用字段名称映射（用于无法匹配模板的字段，如回收站条目）
    const commonFieldNames: Record<string, string> = {
      // 基础通用字段
      'Title': '标题',
      'UserName': '用户名', 
      'Password': '密码',
      'URL': '网址',
      'Notes': '备注',
      'Tags': '标签',
      'Starred': '收藏',
      
      // 身份相关（通用含义）
      'Name': '名称',
      'ID': '标识符',
      'Passport': '护照号',
      'Email': '邮箱',
      'Phone': '电话',
      'Address': '地址',
      'Company': '公司',
      'JobTitle': '职位',
      'Birthday': '生日',
      'Relation': '关系',
      'RealName': '实名',
      'MedicalID': '医保卡号',
      'Nationality': '国籍',
      
      // 金融相关（通用含义）
      'AccountNumber': '账号',
      'BankName': '银行',
      'CardNumber': '卡号',
      'CVV': '安全码',
      'Expiry': '有效期',
      'ExpiryDate': '有效期',
      'PolicyNumber': '保单号',
      'Coverage': '保障范围',
      'Premium': '保费',
      'Beneficiary': '受益人',
      'AccountType': '账户类型',
      'IBAN': '国际银行账号',
      'SwiftCode': 'SWIFT代码',
      'BranchCode': '分行代码',
      'PayPassword': '支付密码',
      'ClaimPhone': '理赔电话',
      
      // 证件相关
      'Number': '证件号码',
      'IssueDate': '签发日期',
      'Issuer': '签发机关',
      
      // 医疗相关
      'Hospital': '医院',
      'Doctor': '医生',
      'PatientID': '患者ID',
      'Diagnosis': '诊断结果',
      'Treatment': '治疗方案',
      'Date': '日期',
      
      // 车辆相关
      'Brand': '品牌',
      'Model': '型号',
      'VIN': 'VIN',
      'Plate': '车牌号',
      'Color': '颜色',
      'PurchaseDate': '购买日期',
      'Insurance': '保险到期',
      'MaintenanceDate': '下次保养日期',
      
      // 技术相关
      'Host': '主机',
      'Port': '端口',
      'Protocol': '协议',
      'Server': '服务器',
      'Database': '数据库',
      'API_Key': 'API密钥',
      'SecretKey': '密钥',
      'PrivateKey': '私钥',
      'PublicKey': '公钥',
      'Certificate': '证书',
      'License': '许可证',
      'Key': 'API Key',
      'Secret': 'API Secret',
      'BaseURL': '基础URL',
      'Documentation': '文档链接',
      'RateLimit': '速率限制',
      'DBname':'数据库名',
      
      // 软件相关
      'LicenseKey': '许可证密钥',
      'RegisteredEmail': '授权邮箱',
      'MaxDevices': '最大设备数',
      
      // 加密货币相关
      'Seed': '助记词',
      'Network': '网络/链',
      'Balance': '余额',
      'CreationDate': '创建日期',
      
      // 其他常见字段
      'Website': '网站',
      'Description': '描述',
      'Comment': '注释',
      'Category': '分类',
      'Type': '类型',
      'Status': '状态',
      'Version': '版本',
      'Location': '位置',
      'Region': '所在地区',
      'Level': '等级',
      'Plan': '套餐',
      'RenewDate': '续费日期',
      'MemberID': '会员号',
      'Points': '积分',
      'Content': '内容'
    };
    
    // 通过关键词判断是否为敏感字段
    const sensitiveKeywords = ['password', 'pwd', 'key', 'secret', 'token', 'seed', 'private', 'cvv', 'pin'];
    const isProtected = sensitiveKeywords.some(keyword => 
      fieldKey.toLowerCase().includes(keyword.toLowerCase())
    );
    
    // 先尝试精确匹配
    let fieldLabel = commonFieldNames[fieldKey];
    
    // 如果精确匹配失败，尝试大小写不敏感匹配
    if (!fieldLabel) {
      const matchedKey = Object.keys(commonFieldNames).find(key => 
        key.toLowerCase() === fieldKey.toLowerCase()
      );
      if (matchedKey) {
        fieldLabel = commonFieldNames[matchedKey];
      }
    }
    
    return {
      label: fieldLabel || fieldKey,
      isProtected
    };
  }

  /**
   * 处理字段排序和渲染数据生成
   * @param fields 字段映射
   * @param groupName 组名
   * @returns 排序后的渲染字段数组
   */
  static processSortedFields(fields: Map<string, string>, groupName?: string): RenderField[] {
    if (!fields) {
      return [];
    }

    // 获取所有有值的字段
    const allFields: string[] = [];
    fields.forEach((value, key) => {
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
      'TOTP', 'Notes', '创建时间', '修改时间'
    ];

    // 按优先级排序字段
    const sortedFields = allFields.sort((a, b) => {
      const aIndex = priorityFields.indexOf(a);
      const bIndex = priorityFields.indexOf(b);
      
      if (aIndex === -1 && bIndex === -1) return a.localeCompare(b);
      if (aIndex === -1) return 1;
      if (bIndex === -1) return -1;
      return aIndex - bIndex;
    });

    // 生成 renderFields 供 UI 渲染
    const renderFields: RenderField[] = [];
    sortedFields.forEach(key => {
      if (key === 'Starred') {
        return; // 不展示收藏标记字段
      }

      const value = fields.get(key);
      if (!value || value.trim().length === 0) {
        return;
      }

      const fieldInfo: FieldInfo = this.getFieldInfo(key, groupName);
      let type: 'password' | 'url' | 'text' = 'text';
      if (fieldInfo.isProtected) {
        type = 'password';
      } else if (key === 'URL' || key === 'Website') {
        type = 'url';
      }

      renderFields.push({
        key,
        label: fieldInfo.label,
        value,
        type
      });
    });

    // 确保创建/修改时间字段始终在最后
    const timeOrder = ['创建时间', '修改时间'];
    const timeFields: RenderField[] = [];
    const otherFields: RenderField[] = [];

    renderFields.forEach(f => {
      if (timeOrder.includes(f.key)) {
        timeFields.push(f);
      } else {
        otherFields.push(f);
      }
    });

    // 按预设顺序排序时间字段
    timeFields.sort((a, b) => timeOrder.indexOf(a.key) - timeOrder.indexOf(b.key));

    return otherFields.concat(timeFields);
  }
} 
