import HelpItemModel from './HelpItemModel'

export const helpItem: HelpItemModel = new HelpItemModel(
  'database_manage',
  '密码库管理',
  $r('app.media.information'),
  `hPassword 使用 KeePass 密码库格式，确保与其他密码管理软件完全兼容。

**密码库创建**
• 首次启动时自动创建 default.kdbx 密码库
• 支持 KeePass 3.x/4.x 格式，默认使用 4.x 格式
• 采用 AES-256 加密算法，密钥派生函数使用 60,000 轮加密
• 支持数据压缩，减少存储空间占用

**密码库位置**
• 文件名：default.kdbx
• 存储位置：应用私有目录，类似 /storage/Users/currentUser/appdata/el2/base/com.mznm.hpassword/haps/entry/files
• 权限保护：仅应用本身可访问
• 复制路径：可以在密码库管理页面复制密码库文件具体路径，打开路径备份密码库文件

**备份与恢复**
• 备份重要性：定期备份可防止设备损坏或误删导致的数据丢失，请务必建立固定的备份计划
• 备份频率：建议每周至少备份一次，或在大量修改后立即备份
• 备份方式：复制 default.kdbx 文件到安全位置，例如云存储、U 盘或电脑
• 多重备份：遵循 3-2-1 策略，至少保留 3 个副本，存储在 2 种介质，其中 1 个离线
• 恢复流程：将备份文件复制回应用私有目录并重新载入即可恢复所有数据

**密码库操作**
• 自动锁定：10 分钟无操作自动锁定保护
• 完整性验证：每次打开都会验证密码库完整性
• 状态持久化：自动保存界面布局和用户偏好
• 实时保存：所有更改立即保存到密码库文件

**兼容性支持**
• 完全兼容 KeePass 2.x 标准格式
• 支持与 KeePass、KeePassXC 等工具互通
• 版本升级：支持从旧版本格式自动升级
• 数据迁移：首次升级时自动迁移数据格式`
) 