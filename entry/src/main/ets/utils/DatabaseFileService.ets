import router from '@ohos.router'
import { KdbxCore } from '../utils/KdbxCore'
import { DatabaseFileManager } from '../utils/DatabaseFileManager'
import PreferencesUtil from '../utils/PreferencesUtil'
import { KdbxCoreManager } from '../utils/KdbxCore'

// 与 MainPage/IndexPage 共用的数据结构
interface DatabaseItem {
  id: string
  name: string
  path: string
  lastModified: string
  size: number
}

export class DatabaseFileService {
  /** 保存数据库到文件（原 MainPage.saveDatabaseToFile） */
  static async saveDatabaseToFile(kdbxCore: KdbxCore | null, fileMgr: DatabaseFileManager | null): Promise<void> {
    try {
      if (!kdbxCore || !fileMgr) {
        console.error('DatabaseFileService', '核心或文件管理器未初始化')
        return
      }

      const database = kdbxCore.getDatabase()
      if (!database) {
        console.error('DatabaseFileService', '数据库实例不存在')
        return
      }

      // 获取当前打开的密码库ID
      const currentId: string = PreferencesUtil.getKdbxCurrentDatabaseIdSync()
      let targetFileName = ''

      if (currentId === 'default' || !currentId) {
        targetFileName = 'default.kdbx'
        console.log('DatabaseFileService', '保存到默认密码库文件:', targetFileName)
      } else {
        try {
          const listJson: string = PreferencesUtil.getKdbxDatabaseListSync()
          const list: DatabaseItem[] = JSON.parse(listJson) as DatabaseItem[]
          const currentDb = list.find(it => it.id === currentId)
          if (currentDb && currentDb.path) {
            targetFileName = currentDb.path
            console.log('DatabaseFileService', '保存到当前密码库文件:', currentDb.name, '路径:', targetFileName)
          } else {
            console.error('DatabaseFileService', '未找到当前密码库信息')
            return
          }
        } catch (e) {
          console.error('DatabaseFileService', '解析数据库列表失败', e)
          return
        }
      }

      if (!targetFileName) {
        console.error('DatabaseFileService', '无法确定目标文件名')
        return
      }

      const saveResult = await fileMgr.saveDatabaseToFile(database, targetFileName)
      if (!saveResult.success) {
        console.error('DatabaseFileService', '数据库保存失败:', saveResult.error)
      } else {
        console.log('DatabaseFileService', '数据库保存成功到:', targetFileName)
      }
    } catch (error) {
      console.error('DatabaseFileService', '保存数据库时发生错误:', error)
    }
  }

  /** 保存并返回 Index 页面 */
  static async returnToIndex(kdbxCore: KdbxCore | null, fileMgr: DatabaseFileManager | null): Promise<void> {
    try {
      await DatabaseFileService.saveDatabaseToFile(kdbxCore, fileMgr)
    } catch (_) {}

    // 清理当前数据库实例
    KdbxCoreManager.getInstance().clearCurrentKdbxCore()

    // 跳转到首页
    router.replaceUrl({ url: 'pages/Index' })
  }
} 