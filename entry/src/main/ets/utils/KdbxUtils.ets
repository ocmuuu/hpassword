import { hilog } from '@kit.PerformanceAnalysisKit';
import { KdbxEntry, KdbxGroup, ProtectedValue } from '../lib';
import { 
  PasswordStrength, 
  PasswordGenerateOptions, 
  EntryField,
  DatabaseStats 
} from './KdbxTypes';

const TAG = 'KdbxUtils';

/**
 * 格式化日期为字符串
 */
export function formatDate(date: Date | null | undefined): string {
  if (!date) return '未知';
  return date.toLocaleString('zh-CN');
}

/**
 * 格式化文件大小
 */
export function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

/**
 * 验证密码强度
 */
export function analyzePasswordStrength(password: string): PasswordStrength {
  if (!password) {
    return {
      score: 0,
      level: 'weak',
      suggestions: ['密码不能为空'],
      hasUppercase: false,
      hasLowercase: false,
      hasNumbers: false,
      hasSymbols: false,
      length: 0
    };
  }

  const hasUppercase = /[A-Z]/.test(password);
  const hasLowercase = /[a-z]/.test(password);
  const hasNumbers = /[0-9]/.test(password);
  const hasSymbols = /[^A-Za-z0-9]/.test(password);
  const length = password.length;

  let score = 0;
  const suggestions: string[] = [];

  // 长度评分
  if (length >= 12) {
    score += 25;
  } else if (length >= 8) {
    score += 15;
  } else if (length >= 6) {
    score += 10;
  } else {
    suggestions.push('密码长度至少需要8个字符');
  }

  // 字符类型评分
  if (hasUppercase) score += 15;
  else suggestions.push('添加大写字母');
  
  if (hasLowercase) score += 15;
  else suggestions.push('添加小写字母');
  
  if (hasNumbers) score += 15;
  else suggestions.push('添加数字');
  
  if (hasSymbols) score += 20;
  else suggestions.push('添加特殊字符');

  // 复杂度加分
  if (length >= 16) score += 10;
  if (hasUppercase && hasLowercase && hasNumbers && hasSymbols) score += 10;

  // 确保分数在0-100之间
  score = Math.min(100, Math.max(0, score));

  let level: 'weak' | 'fair' | 'good' | 'strong' | 'very_strong';
  if (score >= 80) level = 'very_strong';
  else if (score >= 60) level = 'strong';
  else if (score >= 40) level = 'good';
  else if (score >= 20) level = 'fair';
  else level = 'weak';

  return {
    score,
    level,
    suggestions,
    hasUppercase,
    hasLowercase,
    hasNumbers,
    hasSymbols,
    length
  };
}

/**
 * 生成随机密码
 */
export function generatePassword(options: PasswordGenerateOptions): string {
  const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const lowercase = 'abcdefghijklmnopqrstuvwxyz';
  const numbers = '0123456789';
  const symbols = '!@#$%^&*()_+-=[]{}|;:,.<>?';
  const similar = 'il1Lo0O';
  const ambiguous = '{}[]()/\\\'"`~,;.<>';

  let charset = '';
  if (options.includeUppercase) charset += uppercase;
  if (options.includeLowercase) charset += lowercase;
  if (options.includeNumbers) charset += numbers;
  if (options.includeSymbols) charset += symbols;
  if (options.customCharacters) charset += options.customCharacters;

  if (options.excludeSimilar) {
    for (const char of similar) {
      charset = charset.replace(new RegExp(char, 'g'), '');
    }
  }

  if (options.excludeAmbiguous) {
    for (const char of ambiguous) {
      charset = charset.replace(new RegExp('\\' + char, 'g'), '');
    }
  }

  if (charset.length === 0) {
    throw new Error('没有可用的字符集');
  }

  let password = '';
  for (let i = 0; i < options.length; i++) {
    const randomIndex = Math.floor(Math.random() * charset.length);
    password += charset[randomIndex];
  }

  return password;
}

/**
 * 验证邮箱格式
 */
export function isValidEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

/**
 * 验证URL格式
 */
export function isValidUrl(url: string): boolean {
  try {
    // 使用简单的正则表达式验证URL格式
    const urlRegex = /^https?:\/\/.+/;
    return urlRegex.test(url);
  } catch {
    return false;
  }
}

/**
 * 提取条目的所有字段
 */
export function extractEntryFields(entry: KdbxEntry): EntryField[] {
  const fields: EntryField[] = [];
  
  const entries = Array.from(entry.fields.entries());
  for (let i = 0; i < entries.length; i++) {
    const key = entries[i][0];
    const value = entries[i][1];
    
    fields.push({
      key,
      value,
      isProtected: value instanceof ProtectedValue
    });
  }
  
  return fields;
}

/**
 * 获取条目的显示文本
 */
export function getEntryDisplayText(entry: KdbxEntry, fieldName: string): string {
  const field = entry.fields.get(fieldName);
  if (!field) return '';
  
  if (field instanceof ProtectedValue) {
    return field.getText();
  }
  
  return field as string;
}

/**
 * 设置条目字段值
 */
export function setEntryField(entry: KdbxEntry, fieldName: string, value: string, isProtected: boolean = false): void {
  if (isProtected) {
    entry.fields.set(fieldName, ProtectedValue.fromString(value));
  } else {
    entry.fields.set(fieldName, value);
  }
}

/**
 * 计算组的统计信息
 */
export function calculateGroupStats(group: KdbxGroup): DatabaseStats {
  let entries = group.entries.length;
  let groups = 1; // 当前组
  let totalSize = 0;
  let lastModified: Date | undefined;

  // 计算当前组的大小和最后修改时间
  for (let i = 0; i < group.entries.length; i++) {
    const entry = group.entries[i];
    if (entry.times && entry.times.lastModTime) {
      if (!lastModified || entry.times.lastModTime > lastModified) {
        lastModified = entry.times.lastModTime;
      }
    }
    
    // 估算条目大小
    const fields = extractEntryFields(entry);
    for (const field of fields) {
      if (field.value instanceof ProtectedValue) {
        totalSize += field.value.getText().length;
      } else {
        totalSize += (field.value as string).length;
      }
    }
  }

  // 递归计算子组
  for (let i = 0; i < group.groups.length; i++) {
    const childGroup = group.groups[i];
    const childStats = calculateGroupStats(childGroup);
    entries += childStats.entries;
    groups += childStats.groups;
    totalSize += childStats.totalSize;
    
    if (childStats.lastModified) {
      if (!lastModified || childStats.lastModified > lastModified) {
        lastModified = childStats.lastModified;
      }
    }
  }

  return {
    entries,
    groups,
    totalSize,
    lastModified
  };
}

/**
 * 获取组的完整路径
 */
export function getGroupPath(group: KdbxGroup): string {
  const path: string[] = [];
  let current: KdbxGroup | null = group;
  
  while (current) {
    path.unshift(current.name || '未命名');
    current = current.parentGroup || null;
  }
  
  return path.join(' / ');
}

/**
 * 查找组中的条目
 */
export function findEntryInGroup(group: KdbxGroup, entryId: string): KdbxEntry | null {
  // 在当前组中查找
  for (let i = 0; i < group.entries.length; i++) {
    const entry = group.entries[i];
    if (entry.uuid.id === entryId) {
      return entry;
    }
  }
  
  // 在子组中递归查找
  for (let i = 0; i < group.groups.length; i++) {
    const childGroup = group.groups[i];
    const found = findEntryInGroup(childGroup, entryId);
    if (found) {
      return found;
    }
  }
  
  return null;
}

/**
 * 查找组
 */
export function findGroupInGroup(group: KdbxGroup, groupId: string): KdbxGroup | null {
  // 检查当前组
  if (group.uuid.id === groupId) {
    return group;
  }
  
  // 在子组中递归查找
  for (let i = 0; i < group.groups.length; i++) {
    const childGroup = group.groups[i];
    const found = findGroupInGroup(childGroup, groupId);
    if (found) {
      return found;
    }
  }
  
  return null;
}

/**
 * 验证组名是否有效
 */
export function isValidGroupName(name: string): boolean {
  if (!name || name.trim().length === 0) {
    return false;
  }
  
  // 检查是否包含非法字符
  const invalidChars = /[<>:"/\\|?*]/;
  return !invalidChars.test(name);
}

/**
 * 验证条目标题是否有效
 */
export function isValidEntryTitle(title: string): boolean {
  if (!title || title.trim().length === 0) {
    return false;
  }
  
  return title.length <= 255; // 限制标题长度
}

/**
 * 清理和格式化文本
 */
export function cleanText(text: string): string {
  if (!text) return '';
  return text.trim().replace(/\s+/g, ' ');
}

/**
 * 转义HTML特殊字符
 */
export function escapeHtml(text: string): string {
  if (!text) return '';
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * 生成UUID字符串
 */
export function generateUuidString(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c: string) => {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

/**
 * 记录操作日志
 */
export function logOperation(operation: string, details?: Record<string, Object>): void {
  hilog.info(0, TAG, '操作: %{public}s', operation);
  if (details) {
    hilog.info(0, TAG, '详情: %{public}s', JSON.stringify(details));
  }
}

/**
 * 记录错误日志
 */
export function logError(operation: string, error: Error): void {
  hilog.error(0, TAG, '操作失败: %{public}s', operation);
  hilog.error(0, TAG, '错误: %{public}s', error.message);
  if (error.stack) {
    hilog.error(0, TAG, '堆栈: %{public}s', error.stack);
  }
} 