import { EntryItem } from './EntryConverter'

// 随机密码类型配置接口
interface PasswordTypeConfig {
  id: string
  title: string
  type: number
}

export class PasswordGenerator {
  // 三种类型的配置常量
  static readonly PASSWORD_TYPE_CONFIGS: PasswordTypeConfig[] = [
    { id: 'random_pwd_type1', title: '字母数字组合', type: 1 } as PasswordTypeConfig,
    { id: 'random_pwd_type2', title: '字母数字+常用符号', type: 2 } as PasswordTypeConfig,
    { id: 'random_pwd_type3', title: '字母数字+全部符号', type: 3 } as PasswordTypeConfig,
    { id: 'random_pwd_type4', title: '无易混字符', type: 4 } as PasswordTypeConfig,
    { id: 'random_pwd_type5', title: '数字 PIN', type: 5 } as PasswordTypeConfig,
    { id: 'random_pwd_type6', title: '十六进制键', type: 6 } as PasswordTypeConfig
  ]

  /**
   * 生成指定复杂度的随机密码字符串
   * type 对应关系：
   * 1: 大小写字母 + 数字
   * 2: 大小写字母 + 数字 + 常用符号 (@#$%&+)
   * 3: 大小写字母 + 数字 + 所有可打印特殊字符
   * 4: 大小写字母 + 数字（去除易混字符 0O1lI5S2Z）
   * 5: 仅数字
   * 6: 十六进制字符 (0-9A-F)
   */
  static generate(length: number = 16, type: number = 1): string {
    if (length <= 0) {
      return ''
    }

    // 基础字符集合
    const lower = 'abcdefghijklmnopqrstuvwxyz'
    const upper = lower.toUpperCase()
    const digits = '0123456789'
    const commonSymbols = '@#$%&+'
    // 所有可打印特殊字符（排除空格和字母数字）
    const allSymbols = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~" // eslint-disable-line quotes
    const ambiguous = '0O1lI5S2Z'

    let charset: string = ''
    switch (type) {
      case 1:
        charset = lower + upper + digits
        break
      case 2:
        charset = lower + upper + digits + commonSymbols
        break
      case 3:
        charset = lower + upper + digits + allSymbols
        break
      case 4:
        // 去除易混字符
        charset = (lower + upper + digits).split('').filter(ch => !ambiguous.includes(ch)).join('')
        break
      case 5:
        charset = digits
        break
      case 6:
        charset = '0123456789ABCDEF'
        break
      default:
        charset = lower + upper + digits
        break
    }

    if (!charset) {
      charset = lower + upper + digits
    }

    let password = ''
    for (let i = 0; i < length; i++) {
      const randomIndex = Math.floor(Math.random() * charset.length)
      password += charset.charAt(randomIndex)
    }
    return password
  }

  /**
   * 根据配置生成 EntryItem（模拟数据库条目）
   */
  static createEntryItem(cfg: PasswordTypeConfig, length: number = 16): EntryItem {
    const password = PasswordGenerator.generate(length, cfg.type)

    const now = new Date()
    const dateStr = `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}-${now.getDate().toString().padStart(2, '0')}`

    const fields = new Map<string, string>()
    fields.set('Password', password)
    fields.set('Type', cfg.type.toString())
    fields.set('创建时间', dateStr)
    fields.set('修改时间', dateStr)

    return {
      id: cfg.id,
      title: cfg.title,
      username: '',
      notes: '',
      url: '',
      icon: $r('app.media.random'),
      lastModified: dateStr,
      groupId: 'random_password',
      groupName: '随机密码',
      fields
    } as EntryItem
  }

  /**
   * 获取三种随机密码条目列表
   */
  static getRandomPasswordEntryItems(length: number = 16): EntryItem[] {
    const list: EntryItem[] = []
    PasswordGenerator.PASSWORD_TYPE_CONFIGS.forEach((cfg: PasswordTypeConfig) => {
      list.push(PasswordGenerator.createEntryItem(cfg, length))
    })
    return list
  }

  /**
   * 按长度区间批量生成密码列表
   * 默认每种长度生成 countPerLen 条
   */
  static generatePasswordList(type: number, lengths: number[] = [8, 10, 12, 14, 16], countPerLen: number = 3): string[] {
    const list: string[] = []
    lengths.forEach((len) => {
      for (let i = 0; i < countPerLen; i++) {
        list.push(PasswordGenerator.generate(len, type))
      }
    })
    return list
  }
} 