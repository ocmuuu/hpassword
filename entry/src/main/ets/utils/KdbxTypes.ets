import { KdbxEntry, KdbxGroup, KdbxUuid, ProtectedValue } from '../lib';
import { CategoryTemplate } from '../templates/TemplateTypes';

/**
 * 数据库统计信息
 */
export interface DatabaseStats {
  entries: number;
  groups: number;
  totalSize: number;
  lastModified?: Date;
}

/**
 * 条目字段信息
 */
export interface EntryField {
  key: string;
  value: string | ProtectedValue;
  isProtected: boolean;
}

/**
 * 条目创建/更新参数
 */
export interface EntryCreateParams {
  title: string;
  username?: string;
  password?: string;
  url?: string;
  notes?: string;
  customFields?: Map<string, string | ProtectedValue>;
  parentGroup?: KdbxGroup;
  template?: CategoryTemplate;
}

/**
 * 条目更新参数
 */
export interface EntryUpdateParams {
  title?: string;
  username?: string;
  password?: string;
  url?: string;
  notes?: string;
  customFields?: Map<string, string | ProtectedValue>;
  template?: CategoryTemplate;
}

/**
 * 组创建参数
 */
export interface GroupCreateParams {
  name: string;
  notes?: string;
  parentGroup?: KdbxGroup;
}

/**
 * 组更新参数
 */
export interface GroupUpdateParams {
  name?: string;
  notes?: string;
}

/**
 * 搜索条件
 */
export interface SearchCriteria {
  query: string;
  searchInTitles?: boolean;
  searchInUsernames?: boolean;
  searchInUrls?: boolean;
  searchInNotes?: boolean;
  caseSensitive?: boolean;
  useRegex?: boolean;
}

/**
 * 搜索结果
 */
export interface SearchResult {
  entry: KdbxEntry;
  group: KdbxGroup;
  matchedFields: string[];
}

/**
 * 数据库加载选项
 */
export interface DatabaseLoadOptions {
  password: string;
  keyFile?: ArrayBuffer;
  validateIntegrity?: boolean;
}

/**
 * 数据库保存选项
 */
export interface DatabaseSaveOptions {
  compression?: boolean;
  encryptionRounds?: number;
  backupCount?: number;
}

/**
 * 条目过滤器
 */
export interface EntryFilter {
  hasPassword?: boolean;
  hasUrl?: boolean;
  hasNotes?: boolean;
  createdAfter?: Date;
  createdBefore?: Date;
  modifiedAfter?: Date;
  modifiedBefore?: Date;
  groupPath?: string;
}

/**
 * 组过滤器
 */
export interface GroupFilter {
  hasEntries?: boolean;
  hasSubGroups?: boolean;
  minEntryCount?: number;
  maxEntryCount?: number;
  createdAfter?: Date;
  createdBefore?: Date;
}

/**
 * 导出选项
 */
export interface ExportOptions {
  format: 'xml' | 'csv' | 'json';
  includePasswords?: boolean;
  includeNotes?: boolean;
  includeCustomFields?: boolean;
  groupFilter?: GroupFilter;
  entryFilter?: EntryFilter;
}

/**
 * 导入选项
 */
export interface ImportOptions {
  format: 'xml' | 'csv' | 'json';
  targetGroup?: KdbxGroup;
  mergeMode?: 'skip' | 'overwrite' | 'merge';
  validateData?: boolean;
}

/**
 * 操作结果
 */
export interface OperationResult<T> {
  success: boolean;
  data?: T;
  error?: string;
  errorCode?: string;
}

/**
 * 批量操作结果
 */
export interface BatchOperationResult<T> {
  success: boolean;
  results: OperationResult<T>[];
  successCount: number;
  failureCount: number;
  errors: string[];
}

/**
 * 数据库事件类型
 */
export enum DatabaseEventType {
  ENTRY_CREATED = 'entry_created',
  ENTRY_UPDATED = 'entry_updated',
  ENTRY_DELETED = 'entry_deleted',
  GROUP_CREATED = 'group_created',
  GROUP_UPDATED = 'group_updated',
  GROUP_DELETED = 'group_deleted',
  DATABASE_SAVED = 'database_saved',
  DATABASE_LOADED = 'database_loaded'
}

/**
 * 数据库事件
 */
export interface DatabaseEvent {
  type: DatabaseEventType;
  timestamp: Date;
  data?: Record<string, Object>;
  source?: string;
}

/**
 * 数据库监听器
 */
export type DatabaseEventListener = (event: DatabaseEvent) => void;

/**
 * 资源管理器接口
 */
export interface ResourceManager {
  getRawFileEntry(name: string): Promise<RawFileEntry>;
}

/**
 * 原始文件条目接口
 */
export interface RawFileEntry {
  openRawFile(): Promise<ArrayBuffer>;
}

/**
 * 密码强度信息
 */
export interface PasswordStrength {
  score: number; // 0-100
  level: 'weak' | 'fair' | 'good' | 'strong' | 'very_strong';
  suggestions: string[];
  hasUppercase: boolean;
  hasLowercase: boolean;
  hasNumbers: boolean;
  hasSymbols: boolean;
  length: number;
}

/**
 * 密码生成选项
 */
export interface PasswordGenerateOptions {
  length: number;
  includeUppercase: boolean;
  includeLowercase: boolean;
  includeNumbers: boolean;
  includeSymbols: boolean;
  excludeSimilar: boolean;
  excludeAmbiguous: boolean;
  customCharacters?: string;
}

/**
 * 备份信息
 */
export interface BackupInfo {
  timestamp: Date;
  size: number;
  entryCount: number;
  groupCount: number;
  version: string;
  checksum: string;
}

/**
 * 文件信息接口
 */
export interface FileInfo {
  name: string;
  path: string;
  size: number;
  createTime: number;
  modifyTime: number;
  isFile: boolean;
  isDirectory: boolean;
}

/**
 * 条目搜索结果 - 为了兼容性保留EntrySearchResult别名
 */
export interface EntrySearchResult {
  entry: KdbxEntry;
  group: KdbxGroup;
  matchedFields: string[];
}

/**
 * 组信息
 */
export interface GroupInfo {
  id: string;
  name: string;
  path: string;
  entryCount: number;
  subGroupCount: number;
  parentGroupId?: string;
  notes?: string;
  creationTime?: Date;
  lastModTime?: Date;
}

/**
 * 条目信息
 */
export interface EntryInfo {
  id: string;
  title: string;
  username?: string;
  password?: string;
  url?: string;
  notes?: string;
  groupId: string;
  groupPath: string;
  hasPassword: boolean;
  customFields: Record<string, string>;
  creationTime?: Date;
  lastModTime?: Date;
  lastAccessTime?: Date;
}

/**
 * 加载rawfile的日志参数
 */
export interface LoadFromRawFileLogParams {
  fileName: string;
  hasKeyFile: boolean;
}

/**
 * 加载buffer的日志参数
 */
export interface LoadFromBufferLogParams {
  size: number;
}

/**
 * 加载事件数据
 */
export interface LoadEventData {
  version: string;
  size?: number;
  isNew?: boolean;
}

/**
 * 保存事件数据
 */
export interface SaveEventData {
  size: number;
}

/**
 * 通用日志参数接口
 */
export interface LogParams {
  query?: string;
  title?: string;
  entryId?: string;
  groupId?: string;
  targetGroupId?: string;
  targetParentGroupId?: string;
  name?: string;
  fileName?: string;
  hasKeyFile?: boolean;
  size?: number;
  databaseName?: string;
  compression?: string;
  encryptionRounds?: number;
  backupCount?: number;
  kdfRounds?: number;
}

/**
 * 通用事件数据接口
 */
export interface EventData {
  entryId?: string;
  groupId?: string;
  title?: string;
  name?: string;
  parentGroupId?: string;
  changes?: string[];
  action?: string;
  fromGroupId?: string;
  toGroupId?: string;
  fromParentGroupId?: string;
  toParentGroupId?: string;
  newPath?: string;
  sourceEntryId?: string;
  sourceGroupId?: string;
  recursive?: boolean;
  deletedEntries?: number;
  deletedGroups?: number;
  path?: string;
}

 