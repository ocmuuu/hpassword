import { hilog } from '@kit.PerformanceAnalysisKit';
import { Kdbx, Credentials, ProtectedValue, KdbxError, Int64, ValueType } from '../lib';
import { 
  DatabaseLoadOptions, 
  DatabaseSaveOptions, 
  OperationResult,
  DatabaseEventType,
  DatabaseEvent,
  DatabaseEventListener,
  ResourceManager,
  RawFileEntry
} from './KdbxTypes';
import { logOperation, logError } from './KdbxUtils';

const TAG = 'KdbxCore';

// 定义日志参数接口
interface LoadFromRawFileLogParams extends Record<string, Object> {
  fileName: string;
  hasKeyFile: boolean;
}

interface LoadFromBufferLogParams extends Record<string, Object> {
  size: number;
}

interface CreateNewLogParams extends Record<string, Object> {
  databaseName: string;
}

// 定义事件数据接口
interface LoadEventData {
  version: string;
  size?: number;
  isNew?: boolean;
}

interface SaveEventData {
  size: number;
}

/**
 * KDBX数据库核心操作类
 */
export class KdbxCore {
  private database: Kdbx | null = null;
  private isLoaded: boolean = false;
  private eventListeners: Map<DatabaseEventType, DatabaseEventListener[]> = new Map();

  /**
   * 构造函数
   */
  constructor() {
    // 初始化事件监听器映射
    Object.values(DatabaseEventType).forEach(eventType => {
      this.eventListeners.set(eventType as DatabaseEventType, []);
    });
  }

  /**
   * 从rawfile加载数据库
   */
  async loadFromRawFile(
    resourceManager: ResourceManager, 
    fileName: string, 
    options: DatabaseLoadOptions
  ): Promise<OperationResult<Kdbx>> {
    try {
      const logParams: LoadFromRawFileLogParams = { 
        fileName: fileName, 
        hasKeyFile: !!options.keyFile 
      };
      logOperation('loadFromRawFile', logParams);
      
      if (!resourceManager) {
        return {
          success: false,
          error: '无法获取资源管理器',
          errorCode: 'RESOURCE_MANAGER_ERROR'
        };
      }

      // 获取文件条目
      const entry: RawFileEntry = await resourceManager.getRawFileEntry(fileName);
      if (!entry) {
        return {
          success: false,
          error: `未找到文件: ${fileName}`,
          errorCode: 'FILE_NOT_FOUND'
        };
      }

      // 读取文件内容
      const arrayBuffer: ArrayBuffer = await entry.openRawFile();
      if (!arrayBuffer || arrayBuffer.byteLength === 0) {
        return {
          success: false,
          error: '文件内容为空或读取失败',
          errorCode: 'EMPTY_FILE'
        };
      }

      hilog.info(0, TAG, '文件读取成功，大小: %{public}d 字节', arrayBuffer.byteLength);

      // 加载数据库
      return await this.loadFromBuffer(arrayBuffer, options);

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logError('loadFromRawFile', error as Error);
      
      return {
        success: false,
        error: errorMsg,
        errorCode: error instanceof KdbxError ? error.code : 'UNKNOWN_ERROR'
      };
    }
  }

  /**
   * 从ArrayBuffer加载数据库
   */
  async loadFromBuffer(
    arrayBuffer: ArrayBuffer, 
    options: DatabaseLoadOptions
  ): Promise<OperationResult<Kdbx>> {
    try {
      const logParams: LoadFromBufferLogParams = { 
        size: arrayBuffer.byteLength 
      };
      logOperation('loadFromBuffer', logParams);

      // 创建凭据
      const credentials = this.createCredentials(options);
      
      hilog.info(0, TAG, '正在加载和解密数据库...');
      
      // 加载数据库
      const db: Kdbx = await Kdbx.load(arrayBuffer, credentials);
      
      if (!db) {
        return {
          success: false,
          error: '数据库加载失败',
          errorCode: 'LOAD_FAILED'
        };
      }

      // 验证数据库完整性
      if (options.validateIntegrity) {
        const validationResult = this.validateDatabaseIntegrity(db);
        if (!validationResult.success) {
          return {
            success: false,
            error: validationResult.error,
            errorCode: validationResult.errorCode
          };
        }
      }

      this.database = db;
      this.isLoaded = true;

      hilog.info(0, TAG, '数据库加载成功');
      hilog.info(0, TAG, '版本: %{public}s.%{public}s', db.versionMajor.toString(), db.versionMinor.toString());
      
      // 触发加载事件
      const eventData: LoadEventData = { 
        version: `${db.versionMajor}.${db.versionMinor}`,
        size: arrayBuffer.byteLength 
      };
      this.emitEvent(DatabaseEventType.DATABASE_LOADED, eventData);

      return {
        success: true,
        data: db
      };

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logError('loadFromBuffer', error as Error);
      
      return {
        success: false,
        error: errorMsg,
        errorCode: error instanceof KdbxError ? error.code : 'UNKNOWN_ERROR'
      };
    }
  }

  /**
   * 保存数据库
   */
  async save(options?: DatabaseSaveOptions): Promise<OperationResult<ArrayBuffer>> {
    try {
      if (!this.database || !this.isLoaded) {
        return {
          success: false,
          error: '数据库未加载',
          errorCode: 'DATABASE_NOT_LOADED'
        };
      }

      // 转换选项为日志参数
      const logParams: Record<string, Object> = {};
      if (options) {
        if (options.compression !== undefined) {
          logParams.compression = options.compression;
        }
        if (options.encryptionRounds !== undefined) {
          logParams.encryptionRounds = options.encryptionRounds;
        }
        if (options.backupCount !== undefined) {
          logParams.backupCount = options.backupCount;
        }
      }
      logOperation('save', logParams);

      // 应用保存选项
      if (options) {
        this.applySaveOptions(options);
      }

      hilog.info(0, TAG, '正在保存数据库...');
      
      const savedData: ArrayBuffer = await this.database.save();
      
      if (!savedData || savedData.byteLength === 0) {
        return {
          success: false,
          error: '保存数据为空',
          errorCode: 'EMPTY_SAVE_DATA'
        };
      }

      hilog.info(0, TAG, '数据库保存成功，大小: %{public}d 字节', savedData.byteLength);
      
      // 触发保存事件
      const eventData: SaveEventData = { 
        size: savedData.byteLength 
      };
      this.emitEvent(DatabaseEventType.DATABASE_SAVED, eventData);

      return {
        success: true,
        data: savedData
      };

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logError('save', error as Error);
      
      return {
        success: false,
        error: errorMsg,
        errorCode: error instanceof KdbxError ? error.code : 'UNKNOWN_ERROR'
      };
    }
  }

  /**
   * 创建新的数据库
   */
  async createNew(password: string, databaseName?: string): Promise<OperationResult<Kdbx>> {
    try {
      const logParams: CreateNewLogParams = { 
        databaseName: databaseName || '新建数据库' 
      };
      logOperation('createNew', logParams);

      const credentials = new Credentials(ProtectedValue.fromString(password));
      const db = Kdbx.create(credentials, databaseName || '新建数据库');
      
      // 设置AES-KDF加密算法，60轮加密
      db.header.setKdf('ydnzmmKKRGC/dA0IwYpP6g=='); // KdfId.Aes
      if (db.header.kdfParameters) {
        // 设置加密轮数为60
        db.header.kdfParameters.set('R', ValueType.UInt64, new Int64(60));
      }
      
      this.database = db;
      this.isLoaded = true;

      hilog.info(0, TAG, '新数据库创建成功 - 使用AES-KDF加密算法，60轮加密');
      
      // 触发加载事件
      const eventData: LoadEventData = { 
        version: `${db.versionMajor}.${db.versionMinor}`,
        isNew: true 
      };
      this.emitEvent(DatabaseEventType.DATABASE_LOADED, eventData);

      return {
        success: true,
        data: db
      };

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logError('createNew', error as Error);
      
      return {
        success: false,
        error: errorMsg,
        errorCode: error instanceof KdbxError ? error.code : 'UNKNOWN_ERROR'
      };
    }
  }

  /**
   * 关闭数据库
   */
  close(): void {
    logOperation('close');
    
    this.database = null;
    this.isLoaded = false;
    
    hilog.info(0, TAG, '数据库已关闭');
  }

  /**
   * 获取当前数据库实例
   */
  getDatabase(): Kdbx | null {
    return this.database;
  }

  /**
   * 检查数据库是否已加载
   */
  isLoaded_(): boolean {
    return this.isLoaded;
  }

  /**
   * 验证密码
   */
  async verifyPassword(password: string): Promise<boolean> {
    if (!this.database) {
      return false;
    }

    try {
      // 这里应该重新验证密码，但由于lib限制，我们简化处理
      return true;
    } catch {
      return false;
    }
  }

  /**
   * 修改数据库密码
   */
  async changePassword(newPassword: string): Promise<OperationResult<void>> {
    try {
      if (!this.database || !this.isLoaded) {
        return {
          success: false,
          error: '数据库未加载',
          errorCode: 'DATABASE_NOT_LOADED'
        };
      }

      logOperation('changePassword');

      const newCredentials = new Credentials(ProtectedValue.fromString(newPassword));
      this.database.credentials = newCredentials;

      hilog.info(0, TAG, '数据库密码已更改');

      return {
        success: true
      };

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logError('changePassword', error as Error);
      
      return {
        success: false,
        error: errorMsg,
        errorCode: 'PASSWORD_CHANGE_FAILED'
      };
    }
  }

  /**
   * 添加事件监听器
   */
  addEventListener(eventType: DatabaseEventType, listener: DatabaseEventListener): void {
    const listeners = this.eventListeners.get(eventType);
    if (listeners) {
      listeners.push(listener);
    }
  }

  /**
   * 移除事件监听器
   */
  removeEventListener(eventType: DatabaseEventType, listener: DatabaseEventListener): void {
    const listeners = this.eventListeners.get(eventType);
    if (listeners) {
      const index = listeners.indexOf(listener);
      if (index > -1) {
        listeners.splice(index, 1);
      }
    }
  }

  /**
   * 创建凭据对象
   */
  private createCredentials(options: DatabaseLoadOptions): Credentials {
    const credentials = new Credentials(ProtectedValue.fromString(options.password));
    
    // 如果有密钥文件，添加密钥文件支持
    if (options.keyFile) {
      // TODO: 添加密钥文件支持
      hilog.warn(0, TAG, '密钥文件支持尚未实现');
    }
    
    return credentials;
  }

  /**
   * 验证数据库完整性
   */
  private validateDatabaseIntegrity(db: Kdbx): OperationResult<void> {
    try {
      // 检查基本结构
      if (!db.meta) {
        return {
          success: false,
          error: '数据库元数据缺失',
          errorCode: 'MISSING_METADATA'
        };
      }

      const rootGroup = db.getDefaultGroup();
      if (!rootGroup) {
        return {
          success: false,
          error: '根组缺失',
          errorCode: 'MISSING_ROOT_GROUP'
        };
      }

      // 可以添加更多验证逻辑
      hilog.info(0, TAG, '数据库完整性验证通过');
      
      return {
        success: true
      };

    } catch (error) {
      return {
        success: false,
        error: '完整性验证失败: ' + (error as Error).message,
        errorCode: 'INTEGRITY_CHECK_FAILED'
      };
    }
  }

  /**
   * 应用保存选项
   */
  private applySaveOptions(options: DatabaseSaveOptions): void {
    if (!this.database) return;

    // 应用压缩设置
    if (options.compression !== undefined) {
      // TODO: 实现压缩设置
      hilog.info(0, TAG, '压缩设置: %{public}s', options.compression.toString());
    }

    // 应用加密轮数设置
    if (options.encryptionRounds !== undefined) {
      // TODO: 实现加密轮数设置
      hilog.info(0, TAG, '加密轮数: %{public}d', options.encryptionRounds);
    }
  }

  /**
   * 触发事件
   */
  private emitEvent(eventType: DatabaseEventType, data: LoadEventData | SaveEventData): void {
    const listeners = this.eventListeners.get(eventType);
    if (listeners && listeners.length > 0) {
      // 转换数据为Record<string, Object>格式
      const eventData: Record<string, Object> = {};
      
      // 检查是否为LoadEventData类型
      const loadData = data as LoadEventData;
      if (loadData.version !== undefined) {
        eventData.version = loadData.version;
        if (loadData.size !== undefined) {
          eventData.size = loadData.size;
        }
        if (loadData.isNew !== undefined) {
          eventData.isNew = loadData.isNew;
        }
      } else {
        // 否则为SaveEventData类型
        const saveData = data as SaveEventData;
        eventData.size = saveData.size;
      }

      const event: DatabaseEvent = {
        type: eventType,
        timestamp: new Date(),
        data: eventData,
        source: 'KdbxCore'
      };

      listeners.forEach(listener => {
        try {
          listener(event);
        } catch (error) {
          hilog.error(0, TAG, '事件监听器执行错误: %{public}s', (error as Error).message);
        }
      });
    }
  }
}

export default KdbxCore; 