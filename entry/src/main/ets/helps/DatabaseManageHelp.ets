import HelpItemModel from './HelpItemModel'

export const helpItem: HelpItemModel = new HelpItemModel(
  'database_manage',
  '数据库管理',
  $r('app.media.information'),
  `hPassword 使用 KeePass 数据库格式，确保与其他密码管理软件完全兼容。

**数据库创建**
• 首次启动时自动创建 default.kdbx 数据库
• 支持 KeePass 3.x/4.x 格式，默认使用 4.x 格式
• 采用 AES-256 加密算法，密钥派生函数使用 60,000 轮加密
• 支持数据压缩，减少存储空间占用

**数据库操作**
• 自动锁定：10 分钟无操作自动锁定保护
• 完整性验证：每次打开都会验证数据库完整性
• 状态持久化：自动保存界面布局和用户偏好
• 实时保存：所有更改立即保存到数据库文件

**兼容性支持**
• 完全兼容 KeePass 2.x 标准格式
• 支持与 KeePass、KeePassXC 等工具互通
• 版本升级：支持从旧版本格式自动升级
• 数据迁移：首次升级时自动迁移数据格式

**数据库位置**
• 文件名：default.kdbx
• 存储位置：应用私有目录
• 权限保护：仅应用本身可访问`
) 