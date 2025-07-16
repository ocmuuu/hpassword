/**
 * 保存于首选项的原始密码库条目
 */
export interface DatabaseItem {
  id: string
  name: string
  path: string
  lastModified: string
  size: number
}

/**
 * 页面展示用的密码库条目，包含转换后的可读字段
 */
export interface DisplayDatabaseItem extends DatabaseItem {
  /** 文件所在目录（可读路径） */
  displayDir: string
  /** 文件名 */
  displayFileName: string
  /** 格式化后的大小字符串，例如 1.2 MB */
  displaySize: string
}

/**
 * 将字节大小格式化为 MB / KB / B 字符串
 */
export function formatSize(size: number): string {
  if (size >= 1024 * 1024) {
    return `${(size / (1024 * 1024)).toFixed(2)} MB`
  } else if (size >= 1024) {
    return `${(size / 1024).toFixed(1)} KB`
  }
  return `${size} B`
}

/**
 * 获取密码库文件的可读全路径：
 * 1. 已是外部路径则直接返回
 * 2. 内部 /data/storage 路径转换为 /storage/Users/currentUser/appdata 方便备份
 * 3. 仅文件名则拼接 filesDir 并做一次转换
 */
export function getDisplayPath(db: DatabaseItem, context: Context): string {
  if (!db || !db.path) {
    return ''
  }

  // 已包含分隔符说明是路径
  if (db.path.includes('/')) {
    // 内部路径转换为外部可见路径
    if (db.path.startsWith('/data/storage')) {
      try {
        const bundleName: string = ((context as ESObject).bundleName as string) ?? 'com.mznm.hpassword'
        return db.path.replace('/data/storage', '/storage/Users/currentUser/appdata')
          .replace('/base/haps', `/base/${bundleName}/haps`)
      } catch (_) {
        return db.path
      }
    }
    return db.path
  }

  // 仅文件名：拼接 filesDir
  const internalPath = `${context.filesDir}/${db.path}`
  if (internalPath.startsWith('/data/storage')) {
    try {
      const bundleName: string = ((context as ESObject).bundleName as string) ?? 'com.mznm.hpassword'
      return internalPath.replace('/data/storage', '/storage/Users/currentUser/appdata')
        .replace('/base/haps', `/base/${bundleName}/haps`)
    } catch (_) {
      return internalPath
    }
  }
  return internalPath
}

/**
 * 将保存的原始条目转换为页面展示条目
 */
export function convertToDisplayItem(item: DatabaseItem, context: Context): DisplayDatabaseItem {
  const fullPath = getDisplayPath(item, context)

  let displayDir = ''
  let displayFileName = item.path

  if (fullPath.includes('/')) {
    displayDir = fullPath.substring(0, fullPath.lastIndexOf('/'))
    displayFileName = fullPath.substring(fullPath.lastIndexOf('/') + 1)
  } else {
    displayDir = '应用数据目录'
    displayFileName = fullPath
  }

  return {
    id: item.id,
    name: item.name,
    path: item.path,
    lastModified: item.lastModified,
    size: item.size,
    displayDir: displayDir,
    displayFileName: displayFileName,
    displaySize: formatSize(item.size)
  }
}

/**
 * 校验 .kdbx 文件名是否符合规则：仅英文字母、数字、下划线，且以 .kdbx 结尾
 */
export function isValidKdbxFileName(fileName: string): boolean {
  const pattern: RegExp = /^[A-Za-z0-9_]+\.kdbx$/
  return pattern.test(fileName)
} 