import { hilog } from '@kit.PerformanceAnalysisKit';
import { Context } from '@kit.AbilityKit';
import { OperationResult, FileInfo } from './KdbxTypes';
import { Kdbx } from '../lib';
import { logOperation, logError } from './KdbxUtils';
import fs from '@ohos.file.fs';

const TAG = 'DatabaseFileManager';

/**
 * 数据库文件管理器 - 处理通用的文件操作
 */
export class DatabaseFileManager {
  private appContext: Context | null = null;

  constructor(ctx?: Context) {
    if (ctx) {
      this.appContext = ctx;
    }
  }

  /**
   * 设置应用上下文
   */
  setContext(ctx: Context): void {
    this.appContext = ctx;
  }

  /**
   * 检查文件是否存在
   */
  async fileExists(fileName: string): Promise<boolean> {
    try {
      if (!this.appContext) {
        return false;
      }

      const filePath = this.getFilePath(fileName);
      
      // 检查文件是否存在
      try {
        await fs.access(filePath);
        return true;
      } catch {
        return false;
      }
    } catch (error) {
      logError('fileExists', error as Error);
      return false;
    }
  }

  /**
   * 保存数据库到文件
   */
  async saveDatabaseToFile(database: Kdbx, fileName: string): Promise<OperationResult<string>> {
    try {
      logOperation('saveDatabaseToFile');

      if (!this.appContext) {
        return {
          success: false,
          error: '应用上下文未初始化',
          errorCode: 'CONTEXT_NOT_INITIALIZED'
        };
      }

      // 保存数据库为ArrayBuffer
      const arrayBuffer = await database.save();
      
      // 写入文件
      const filePath = this.getFilePath(fileName);
      
      const file = await fs.open(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      await fs.write(file.fd, arrayBuffer);
      await fs.close(file.fd);

      hilog.info(0, TAG, '数据库文件保存成功: %{public}s, 大小: %{public}d 字节', 
        filePath, arrayBuffer.byteLength);

      return {
        success: true,
        data: filePath
      };

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logError('saveDatabaseToFile', error as Error);
      
      return {
        success: false,
        error: errorMsg,
        errorCode: 'FILE_SAVE_FAILED'
      };
    }
  }

  /**
   * 从文件读取数据库
   */
  async readDatabaseFromFile(fileName: string): Promise<OperationResult<ArrayBuffer>> {
    try {
      logOperation('readDatabaseFromFile');

      if (!this.appContext) {
        return {
          success: false,
          error: '应用上下文未初始化',
          errorCode: 'CONTEXT_NOT_INITIALIZED'
        };
      }

      const filePath = this.getFilePath(fileName);
      
      // 获取文件信息
      const stat = await fs.stat(filePath);
      if (stat.size === 0) {
        return {
          success: false,
          error: '数据库文件为空',
          errorCode: 'EMPTY_FILE'
        };
      }

      // 读取文件
      const file = await fs.open(filePath, fs.OpenMode.READ_ONLY);
      const arrayBuffer = new ArrayBuffer(stat.size);
      await fs.read(file.fd, arrayBuffer);
      await fs.close(file.fd);

      hilog.info(0, TAG, '数据库文件读取成功: %{public}s, 大小: %{public}d 字节', 
        filePath, arrayBuffer.byteLength);

      return {
        success: true,
        data: arrayBuffer
      };

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logError('readDatabaseFromFile', error as Error);
      
      return {
        success: false,
        error: errorMsg,
        errorCode: 'FILE_READ_FAILED'
      };
    }
  }

  /**
   * 删除文件
   */
  async deleteFile(fileName: string): Promise<OperationResult<void>> {
    try {
      logOperation('deleteFile');

      if (!this.appContext) {
        return {
          success: false,
          error: '应用上下文未初始化',
          errorCode: 'CONTEXT_NOT_INITIALIZED'
        };
      }

      const filePath = this.getFilePath(fileName);
      
      // 检查文件是否存在
      if (!(await this.fileExists(fileName))) {
        return {
          success: true // 文件不存在，认为删除成功
        };
      }

      // 删除文件
      await fs.unlink(filePath);

      hilog.info(0, TAG, '文件删除成功: %{public}s', filePath);
      
      return {
        success: true
      };

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logError('deleteFile', error as Error);
      
      return {
        success: false,
        error: errorMsg,
        errorCode: 'DELETE_FAILED'
      };
    }
  }

  /**
   * 获取文件完整路径
   */
  getFilePath(fileName: string): string {
    if (!this.appContext) {
      throw new Error('应用上下文未初始化');
    }
    return `${this.appContext.filesDir}/${fileName}`;
  }

  /**
   * 获取文件列表
   */
  async getFileList(extension?: string): Promise<OperationResult<string[]>> {
    try {
      logOperation('getFileList');

      if (!this.appContext) {
        return {
          success: false,
          error: '应用上下文未初始化',
          errorCode: 'CONTEXT_NOT_INITIALIZED'
        };
      }

      const filesDir = this.appContext.filesDir;
      
      // 读取目录内容
      const files: string[] = await fs.listFile(filesDir);
      
      // 过滤文件
      let filteredFiles: string[] = files;
      if (extension) {
        filteredFiles = files.filter((file: string) => file.endsWith(extension));
      }

      hilog.info(0, TAG, '获取文件列表成功，共 %{public}d 个文件', filteredFiles.length);
      
      return {
        success: true,
        data: filteredFiles
      };

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logError('getFileList', error as Error);
      
      return {
        success: false,
        error: errorMsg,
        errorCode: 'LIST_FILES_FAILED'
      };
    }
  }

  /**
   * 获取文件信息
   */
  async getFileInfo(fileName: string): Promise<OperationResult<FileInfo>> {
    try {
      logOperation('getFileInfo');

      if (!this.appContext) {
        return {
          success: false,
          error: '应用上下文未初始化',
          errorCode: 'CONTEXT_NOT_INITIALIZED'
        };
      }

      const filePath = this.getFilePath(fileName);
      
      // 检查文件是否存在
      if (!(await this.fileExists(fileName))) {
        return {
          success: false,
          error: '文件不存在',
          errorCode: 'FILE_NOT_FOUND'
        };
      }

      const stat = await fs.stat(filePath);

      const fileInfo: FileInfo = {
        name: fileName,
        path: filePath,
        size: stat.size,
        createTime: stat.ctime,
        modifyTime: stat.mtime,
        isFile: stat.isFile(),
        isDirectory: stat.isDirectory()
      };

      hilog.info(0, TAG, '获取文件信息成功: %{public}s', fileName);
      
      return {
        success: true,
        data: fileInfo
      };

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logError('getFileInfo', error as Error);
      
      return {
        success: false,
        error: errorMsg,
        errorCode: 'GET_FILE_INFO_FAILED'
      };
    }
  }

  /**
   * 复制文件
   */
  async copyFile(sourceFileName: string, targetFileName: string): Promise<OperationResult<string>> {
    try {
      logOperation('copyFile');

      if (!this.appContext) {
        return {
          success: false,
          error: '应用上下文未初始化',
          errorCode: 'CONTEXT_NOT_INITIALIZED'
        };
      }

      const sourcePath = this.getFilePath(sourceFileName);
      const targetPath = this.getFilePath(targetFileName);
      
      // 检查源文件是否存在
      if (!(await this.fileExists(sourceFileName))) {
        return {
          success: false,
          error: '源文件不存在',
          errorCode: 'SOURCE_FILE_NOT_FOUND'
        };
      }

      await fs.copyFile(sourcePath, targetPath);

      hilog.info(0, TAG, '文件复制成功: %{public}s -> %{public}s', sourcePath, targetPath);
      
      return {
        success: true,
        data: targetPath
      };

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logError('copyFile', error as Error);
      
      return {
        success: false,
        error: errorMsg,
        errorCode: 'COPY_FILE_FAILED'
      };
    }
  }
}

 