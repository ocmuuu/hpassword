import { hilog } from '@kit.PerformanceAnalysisKit';
import { Kdbx, Credentials, ProtectedValue, KdbxGroup, KdbxEntry, KdbxError } from '../lib';

// ---- 类型声明，避免在接口中直接内联对象文字 ----
export interface RawFileEntry { openRawFile(): Promise<ArrayBuffer>; }
export interface ResourceManager { getRawFileEntry(name: string): Promise<RawFileEntry>; }

// 统计信息接口
interface DatabaseStats {
  entries: number;
  groups: number;
}

const TAG = 'KdbxReader';

/**
 * 从给定文件路径读取并解析 KDBX 数据库，然后将所有项目信息输出到日志。
 *
 * @param filePath 设备上的文件绝对路径，例如"/data/storage/el2/base/haps/entry/files/Database.kdbx"。
 * @param password 数据库口令。
 */
// export async function readKdbxFromPath(filePath: string, password: string): Promise<void> {
//   // 已废弃，保留占位
// }

/**
 * 从 rawfile 目录读取并解析 KDBX。
 * @param rm ResourceManager。
 * @param fileName rawfile 文件名（含后缀）。
 * @param password 数据库口令。
 */
export async function readKdbxFromRawFile(rm: ResourceManager, fileName: string, password: string): Promise<void> {
  try {
    hilog.info(0, TAG, '=== 开始读取 KDBX 文件 ===');
    hilog.info(0, TAG, '文件名: %{public}s', fileName);
    hilog.info(0, TAG, '密码长度: %{public}d', password.length);
    
    if (!rm) {
      hilog.error(0, TAG, '无法获取 resourceManager');
      return;
    }
    hilog.info(0, TAG, '尝试从 rawfile 加载 %{public}s', fileName);

    hilog.info(0, TAG, '正在获取 rawfile 条目...');
    const entry = await rm.getRawFileEntry(fileName);
    if (!entry) {
      hilog.error(0, TAG, '未找到 rawfile %{public}s', fileName);
      return;
    }
    hilog.info(0, TAG, 'rawfile 条目获取成功');
    
    hilog.info(0, TAG, '正在读取文件内容...');
    const arrayBuffer: ArrayBuffer = await entry.openRawFile();
    if (!arrayBuffer) {
      hilog.error(0, TAG, 'rawfile 读取失败');
      return;
    }
    hilog.info(0, TAG, '文件读取成功，大小: %{public}d bytes', arrayBuffer.byteLength);

    await parseAndPrintKdbx(arrayBuffer, password);
  } catch (err) { // eslint-disable-line arkts-no-any-unknown
    hilog.error(0, TAG, 'readKDBX失败: %{public}s', JSON.stringify(err as object));
    hilog.error(0, TAG, '错误详情: %{public}s', (err as Error).message || 'Unknown error');
    hilog.error(0, TAG, '错误堆栈: %{public}s', (err as Error).stack || 'No stack trace');
    
    // 特殊处理 KdbxError
    if (err instanceof KdbxError) {
      hilog.error(0, TAG, 'KdbxError 代码: %{public}s', err.code);
      hilog.error(0, TAG, 'KdbxError 消息: %{public}s', err.message);
    }
  }
}

async function parseAndPrintKdbx(arrayBuffer: ArrayBuffer, password: string): Promise<void> {
  hilog.info(0, TAG, '=== 开始解析 KDBX 数据库 ===');
  hilog.info(0, TAG, '数据库文件大小: %{public}d 字节', arrayBuffer.byteLength);
  hilog.info(0, TAG, '创建凭据对象...');
  const credentials = new Credentials(ProtectedValue.fromString(password));
  hilog.info(0, TAG, '凭据对象创建成功');
  
  hilog.info(0, TAG, '正在加载和解密数据库...');
  hilog.info(0, TAG, '注意：AES-KDF 计算可能需要几秒钟，请耐心等待...');
  const db: Kdbx = await Kdbx.load(arrayBuffer, credentials);
  hilog.info(0, TAG, '数据库已成功解密，开始遍历内容');
  
  // 打印数据库基本信息
  hilog.info(0, TAG, '=== 数据库信息 ===');
  hilog.info(0, TAG, '版本: %{public}s.%{public}s', db.versionMajor.toString(), db.versionMinor.toString());
  hilog.info(0, TAG, '生成器: %{public}s', db.meta.generator || '未知');
  hilog.info(0, TAG, '数据库名称: %{public}s', db.meta.name || '未命名');
  hilog.info(0, TAG, '数据库描述: %{public}s', db.meta.desc || '无描述');
  hilog.info(0, TAG, '名称修改时间: %{public}s', db.meta.nameChanged ? db.meta.nameChanged.toString() : '未知');
  hilog.info(0, TAG, '描述修改时间: %{public}s', db.meta.descChanged ? db.meta.descChanged.toString() : '未知');
  
  hilog.info(0, TAG, '获取默认组...');
  const root = db.getDefaultGroup();
  if (root) {
    hilog.info(0, TAG, '默认组获取成功，组名: %{public}s', root.name || '(无名称)');
    hilog.info(0, TAG, '=== 开始遍历数据库内容 ===');
    printGroup(root, 0);
    hilog.info(0, TAG, '=== 数据库内容遍历完成 ===');
    
    // 统计信息
    const stats = countEntriesAndGroups(root);
    hilog.info(0, TAG, '=== 统计信息 ===');
    hilog.info(0, TAG, '总组数: %{public}d', stats.groups);
    hilog.info(0, TAG, '总条目数: %{public}d', stats.entries);
  } else {
    hilog.warn(0, TAG, '数据库缺省组不存在');
  }
}

function printGroup(group: KdbxGroup, depth: number): void {
  const indent = '  '.repeat(depth);
  
  hilog.info(0, TAG, '%{public}s组: %{public}s', indent, group.name || '未命名');
  if (group.notes) {
    hilog.info(0, TAG, '%{public}s  备注: %{public}s', indent, group.notes);
  }
  
  // 打印条目
  group.entries.forEach((entry: KdbxEntry) => {
    printEntry(entry, depth + 1);
  });

  // 递归打印子组
  group.groups.forEach((sub: KdbxGroup) => {
    printGroup(sub, depth + 1);
  });
}

function printEntry(entry: KdbxEntry, depth: number): void {
  const indent = '  '.repeat(depth);
  
  // 获取标题
  const title = entry.fields.get('Title');
  const titleText = title instanceof ProtectedValue ? title.getText() : title;
  hilog.info(0, TAG, '%{public}s条目: %{public}s', indent, titleText || '未命名');
  
  // 打印所有字段
  const entries = Array.from(entry.fields.entries());
  for (let i = 0; i < entries.length; i++) {
    const key = entries[i][0];
    const value = entries[i][1];
    let fieldValue: string;
    if (value instanceof ProtectedValue) {
      fieldValue = value.getText();
    } else {
      fieldValue = value as string;
    }
    if (fieldValue && fieldValue.trim()) {
      hilog.info(0, TAG, '%{public}s  %{public}s: %{public}s', indent, key, fieldValue);
    }
  }
  
  // 打印自定义数据
  if (entry.customData && entry.customData.size > 0) {
    hilog.info(0, TAG, '%{public}s  自定义数据:', indent);
    const customEntries = Array.from(entry.customData.entries());
    for (let i = 0; i < customEntries.length; i++) {
      const key = customEntries[i][0];
      const value = customEntries[i][1];
      hilog.info(0, TAG, '%{public}s    %{public}s: %{public}s', indent, key, value);
    }
  }
  
  // 打印时间信息
  if (entry.times) {
    hilog.info(0, TAG, '%{public}s  创建时间: %{public}s', indent, entry.times.creationTime ? entry.times.creationTime.toString() : '未知');
    hilog.info(0, TAG, '%{public}s  最后修改: %{public}s', indent, entry.times.lastModTime ? entry.times.lastModTime.toString() : '未知');
    hilog.info(0, TAG, '%{public}s  最后访问: %{public}s', indent, entry.times.lastAccessTime ? entry.times.lastAccessTime.toString() : '未知');
  }
  
  hilog.info(0, TAG, ''); // 空行分隔
}

function countEntriesAndGroups(group: KdbxGroup): DatabaseStats {
  let entries = group.entries.length;
  let groups = 1; // 当前组
  
  for (let i = 0; i < group.groups.length; i++) {
    const childGroup = group.groups[i];
    const childStats = countEntriesAndGroups(childGroup);
    entries += childStats.entries;
    groups += childStats.groups;
  }
  
  const result: DatabaseStats = {
    entries: entries,
    groups: groups
  };
  return result;
}

// (原 gunzipSync 实现已移动至 lib/utils/fflate-shim.ts，无需在此重复) 