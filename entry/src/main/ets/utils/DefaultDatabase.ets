import { hilog } from '@kit.PerformanceAnalysisKit';
import { Context } from '@kit.AbilityKit';
import { KdbxCore } from './KdbxCore';
import { DatabaseFileManager } from './DatabaseFileManager';
import { OperationResult } from './KdbxTypes';
import { logOperation, logError } from './KdbxUtils';
import { DEFAULT_KDF_ROUNDS, getSecurityLevelName } from './KdbxConstants';

const TAG = 'DefaultDatabase';
const DEFAULT_DATABASE_NAME = 'default.kdbx';
const DEFAULT_DATABASE_DISPLAY_NAME = '默认密码库';

/**
 * 默认密码库管理器 - 专门处理默认密码库的检测和创建
 */
export class DefaultDatabase {
  private static instance: DefaultDatabase | null = null;
  private fileManager: DatabaseFileManager;

  private constructor() {
    this.fileManager = new DatabaseFileManager();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): DefaultDatabase {
    if (!DefaultDatabase.instance) {
      DefaultDatabase.instance = new DefaultDatabase();
    }
    return DefaultDatabase.instance;
  }

  /**
   * 初始化应用上下文
   */
  setContext(ctx: Context): void {
    this.fileManager.setContext(ctx);
  }

  /**
   * 检查默认密码库是否存在
   */
  async exists(): Promise<boolean> {
    try {
      return await this.fileManager.fileExists(DEFAULT_DATABASE_NAME);
    } catch (error) {
      logError('exists', error as Error);
      return false;
    }
  }

  /**
   * 创建默认密码库
   */
  async create(password: string, kdfRounds?: number): Promise<OperationResult<string>> {
    try {
      logOperation('create');

      // 检查是否已存在
      if (await this.exists()) {
        return {
          success: false,
          error: '默认密码库已存在',
          errorCode: 'DATABASE_ALREADY_EXISTS'
        };
      }

      // 创建KdbxCore实例
      const kdbxCore = new KdbxCore();
      
      // 使用传入的轮数或默认值
      const actualKdfRounds = kdfRounds || DEFAULT_KDF_ROUNDS;
      
      // 创建新数据库（使用AES-KDF加密）
      const createResult = await kdbxCore.createNew(password, DEFAULT_DATABASE_DISPLAY_NAME, actualKdfRounds);
      // 为软删除功能提前创建回收站
      if (createResult.success && createResult.data) {
        // createNew 返回的 data 已经是 Kdbx 实例
        const dbForRecycle = createResult.data;
        dbForRecycle.createRecycleBin();
      }
      if (!createResult.success || !createResult.data) {
        return {
          success: false,
          error: createResult.error || '创建数据库失败',
          errorCode: createResult.errorCode || 'CREATE_FAILED'
        };
      }

      // 保存数据库到文件
      const saveResult = await this.fileManager.saveDatabaseToFile(createResult.data, DEFAULT_DATABASE_NAME);
      if (!saveResult.success) {
        return {
          success: false,
          error: saveResult.error || '保存数据库失败',
          errorCode: saveResult.errorCode || 'SAVE_FAILED'
        };
      }

      const securityLevel = getSecurityLevelName(actualKdfRounds);
      hilog.info(0, TAG, `默认密码库创建成功 - AES-KDF加密，${actualKdfRounds}轮（${securityLevel}级别）`);
      
      return {
        success: true,
        data: saveResult.data || this.getDefaultDatabasePath()
      };

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logError('create', error as Error);
      
      return {
        success: false,
        error: errorMsg,
        errorCode: 'UNKNOWN_ERROR'
      };
    }
  }

  /**
   * 打开默认密码库
   */
  async open(password: string): Promise<OperationResult<KdbxCore>> {
    try {
      logOperation('open');

      // 检查文件是否存在
      if (!(await this.exists())) {
        return {
          success: false,
          error: '默认密码库不存在',
          errorCode: 'DATABASE_NOT_FOUND'
        };
      }

      // 读取数据库文件
      const readResult = await this.fileManager.readDatabaseFromFile(DEFAULT_DATABASE_NAME);
      if (!readResult.success || !readResult.data) {
        return {
          success: false,
          error: readResult.error || '读取数据库文件失败',
          errorCode: readResult.errorCode || 'READ_FAILED'
        };
      }

      // 创建KdbxCore实例并加载数据库
      const kdbxCore = new KdbxCore();
      const loadResult = await kdbxCore.loadFromBuffer(readResult.data, {
        password: password,
        validateIntegrity: true
      });

      // 确保回收站存在
      if (loadResult.success) {
        const dbOpened = kdbxCore.getDatabase();
        if (dbOpened) {
          dbOpened.createRecycleBin();
        }
      }

      if (!loadResult.success) {
        return {
          success: false,
          error: loadResult.error || '加载数据库失败',
          errorCode: loadResult.errorCode || 'LOAD_FAILED'
        };
      }

      hilog.info(0, TAG, '默认密码库打开成功');
      
      return {
        success: true,
        data: kdbxCore
      };

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logError('open', error as Error);
      
      return {
        success: false,
        error: errorMsg,
        errorCode: 'UNKNOWN_ERROR'
      };
    }
  }

  /**
   * 保存默认密码库
   */
  async saveDatabase(kdbxCore: KdbxCore): Promise<OperationResult<string>> {
    try {
      logOperation('saveDatabase');

      if (!kdbxCore.isLoaded_()) {
        return {
          success: false,
          error: '数据库未加载',
          errorCode: 'DATABASE_NOT_LOADED'
        };
      }

      const database = kdbxCore.getDatabase();
      if (!database) {
        return {
          success: false,
          error: '无法获取数据库实例',
          errorCode: 'DATABASE_INSTANCE_NULL'
        };
      }

      // 保存数据库到文件
      const saveResult = await this.fileManager.saveDatabaseToFile(database, DEFAULT_DATABASE_NAME);
      if (!saveResult.success) {
        return {
          success: false,
          error: saveResult.error || '保存数据库失败',
          errorCode: saveResult.errorCode || 'SAVE_FAILED'
        };
      }

      hilog.info(0, TAG, '默认密码库保存成功');
      
      return {
        success: true,
        data: saveResult.data || this.getDefaultDatabasePath()
      };

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logError('saveDatabase', error as Error);
      
      return {
        success: false,
        error: errorMsg,
        errorCode: 'UNKNOWN_ERROR'
      };
    }
  }

  /**
   * 删除默认密码库
   */
  async delete(): Promise<OperationResult<void>> {
    try {
      logOperation('delete');

      const deleteResult = await this.fileManager.deleteFile(DEFAULT_DATABASE_NAME);
      if (!deleteResult.success) {
        return {
          success: false,
          error: deleteResult.error || '删除默认密码库失败',
          errorCode: deleteResult.errorCode || 'DELETE_FAILED'
        };
      }

      hilog.info(0, TAG, '默认密码库删除成功');
      
      return {
        success: true
      };

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logError('delete', error as Error);
      
      return {
        success: false,
        error: errorMsg,
        errorCode: 'DELETE_FAILED'
      };
    }
  }

  /**
   * 获取默认数据库路径
   */
  getDefaultDatabasePath(): string {
    return this.fileManager.getFilePath(DEFAULT_DATABASE_NAME);
  }

  /**
   * 获取默认数据库显示名称
   */
  getDefaultDatabaseDisplayName(): string {
    return DEFAULT_DATABASE_DISPLAY_NAME;
  }

  /**
   * 获取默认数据库文件名
   */
  getDefaultDatabaseFileName(): string {
    return DEFAULT_DATABASE_NAME;
  }
} 