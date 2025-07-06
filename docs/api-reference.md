# hPassword API 参考文档

本文档提供hPassword项目的详细API接口说明，面向需要集成或扩展hPassword功能的开发者。

## 📖 目录

1. [API概述](#api概述)
2. [核心API](#核心api)
3. [数据类型](#数据类型)
4. [错误处理](#错误处理)
5. [代码示例](#代码示例)
6. [最佳实践](#最佳实践)

## 🎯 API概述

### 架构设计

hPassword采用分层架构设计，提供以下几个层级的API：

```
┌─────────────────────────────────────┐
│            UI Layer                 │ <- 页面组件和用户交互
├─────────────────────────────────────┤
│         Business Layer              │ <- 业务逻辑API
├─────────────────────────────────────┤
│          Data Layer                 │ <- 数据访问API
├─────────────────────────────────────┤
│         Security Layer              │ <- 安全和加密API
└─────────────────────────────────────┘
```

### API特点

- **类型安全**: 所有API都有完整的TypeScript类型定义
- **异步操作**: 支持Promise和async/await模式
- **错误处理**: 统一的错误处理机制
- **内存安全**: 自动管理敏感数据的内存清理

## 🔧 核心API

### KeePass格式支持

hPassword实现了完整的KeePass数据库格式支持，包括格式解析、加密算法、版本兼容等核心功能。

#### 支持的格式版本

```typescript
// 版本支持范围
export interface KeePassVersionSupport {
  minVersion: { major: 3, minor: 0 }
  maxVersion: { major: 4, minor: 1 }
  defaultVersion: { major: 4, minor: 0 }
}

// 版本特性对比
export interface VersionFeatures {
  kdbx3: {
    encryption: ['AES-256']
    kdf: ['AES-KDF']
    compression: ['GZip']
    binaries: 'embedded'
    customData: false
    tags: false
  }
  
  kdbx4: {
    encryption: ['AES-256', 'ChaCha20']
    kdf: ['AES-KDF'] // Argon2在规划中
    compression: ['GZip']
    binaries: 'external'
    customData: true
    tags: true
  }
}
```

#### 版本检测和控制

```typescript
// 数据库版本信息
export class Kdbx {
  // 获取版本信息
  get versionMajor(): number        // 主版本号（3 或 4）
  get versionMinor(): number        // 次版本号
  
  // 版本检查
  versionIsAtLeast(major: number, minor: number): boolean
  
  // 版本设置
  setVersion(version: 3 | 4): void
  
  // 升级数据库
  upgrade(): void
}
```

#### 技术栈实现

hPassword基于kdbxweb库进行开发，针对HarmonyOS平台优化：

- **格式解析**: 基于kdbxweb的KDBX格式解析和生成
- **加密支持**: AES-256、ChaCha20、Salsa20
- **密钥派生**: 当前支持AES-KDF，Argon2在开发规划中
- **压缩支持**: 使用fflate库进行数据压缩
- **内存保护**: ProtectedValue机制保护敏感数据
- **跨平台兼容**: 与KeePass、KeePassXC等工具完全兼容

### KdbxCore - 数据库核心管理

KdbxCore是hPassword的核心类，提供数据库的创建、加载、保存等基础功能。

#### 类定义

```typescript
export class KdbxCore {
  private database: Kdbx;
  private credentials: KdbxCredentials;
  
  // 静态方法
  static create(password: string): Promise<KdbxCore>;
  static load(data: ArrayBuffer, password: string): Promise<KdbxCore>;
  
  // 实例方法
  getDatabase(): Kdbx;
  save(): Promise<ArrayBuffer>;
  changePassword(newPassword: string): Promise<void>;
}
```

#### 方法详解

##### `KdbxCore.create(password: string): Promise<KdbxCore>`

创建新的KeePass数据库（使用KeePass 4.x格式）。

**参数**:
- `password`: 主密码字符串

**返回值**: Promise\<KdbxCore\> - 新创建的数据库实例

**格式特性**:
- 默认使用KeePass 4.0格式
- 支持AES-256和ChaCha20加密
- 支持Argon2密钥派生函数
- 启用数据压缩

**示例**:
```typescript
try {
  const core = await KdbxCore.create('mySecurePassword123');
  const db = core.getDatabase();
  console.log('数据库创建成功');
  console.log('数据库版本:', db.versionMajor, '.', db.versionMinor);
} catch (error) {
  console.error('创建失败:', error.message);
}
```

##### `KdbxCore.load(data: ArrayBuffer, password: string): Promise<KdbxCore>`

加载现有的KeePass数据库文件（支持KeePass 3.x/4.x格式）。

**参数**:
- `data`: 数据库文件的二进制数据
- `password`: 解锁密码

**返回值**: Promise\<KdbxCore\> - 加载的数据库实例

**格式兼容性**:
- 完全支持KeePass 3.x格式文件
- 完全支持KeePass 4.x格式文件
- 自动检测文件格式版本
- 向后兼容旧版本特性

**示例**:
```typescript
try {
  const fileData = await readDatabaseFile();
  const core = await KdbxCore.load(fileData, 'myPassword');
  const db = core.getDatabase();
  
  console.log('数据库加载成功');
  console.log('检测到版本:', db.versionMajor, '.', db.versionMinor);
  
  // 检查版本特性
  if (db.versionIsAtLeast(4, 0)) {
    console.log('支持KeePass 4.x高级特性');
  }
} catch (error) {
  console.error('加载失败:', error.message);
}
```

##### `save(): Promise<ArrayBuffer>`

保存数据库到二进制格式。

**返回值**: Promise\<ArrayBuffer\> - 加密后的数据库二进制数据

**示例**:
```typescript
try {
  const savedData = await core.save();
  await writeDatabaseFile(savedData);
  console.log('数据库保存成功');
} catch (error) {
  console.error('保存失败:', error.message);
}
```

### KdbxEntryManager - 条目管理

管理数据库中的密码条目，提供CRUD操作。

#### 类定义

```typescript
export class KdbxEntryManager {
  constructor(database: Kdbx);
  
  createEntry(groupId: string, template: Template): OperationResult<KdbxEntry>;
  updateEntry(entry: KdbxEntry, fields: Map<string, string>): OperationResult<void>;
  deleteEntry(entry: KdbxEntry): OperationResult<void>;
  toggleEntryStarred(entry: KdbxEntry): OperationResult<void>;
  isEntryStarred(entry: KdbxEntry): boolean;
}
```

#### 方法详解

##### `createEntry(groupId: string, template: Template): OperationResult<KdbxEntry>`

在指定分组中创建新条目。

**参数**:
- `groupId`: 目标分组的UUID
- `template`: 条目模板

**返回值**: OperationResult\<KdbxEntry\> - 操作结果和创建的条目

**示例**:
```typescript
const manager = new KdbxEntryManager(database);
const result = manager.createEntry(groupId, LoginTemplate);

if (result.success && result.data) {
  console.log('条目创建成功:', result.data.uuid);
} else {
  console.error('创建失败:', result.error);
}
```

##### `updateEntry(entry: KdbxEntry, fields: Map<string, string>): OperationResult<void>`

更新现有条目的字段。

**参数**:
- `entry`: 要更新的条目对象
- `fields`: 新的字段值映射

**返回值**: OperationResult\<void\> - 操作结果

**示例**:
```typescript
const fields = new Map([
  ['Title', '新标题'],
  ['UserName', 'newuser@example.com'],
  ['Password', 'newSecurePassword']
]);

const result = manager.updateEntry(entry, fields);
if (result.success) {
  console.log('条目更新成功');
}
```

### KdbxQuery - 数据查询

提供灵活的数据查询和搜索功能。

#### 类定义

```typescript
export class KdbxQuery {
  constructor(database: Kdbx);
  
  getAllEntries(): OperationResult<KdbxEntry[]>;
  getEntriesByGroup(groupId: string): OperationResult<KdbxEntry[]>;
  getStarredEntries(): OperationResult<KdbxEntry[]>;
  searchEntries(criteria: SearchCriteria): OperationResult<SearchResult[]>;
  findEntryById(id: string): OperationResult<KdbxEntry>;
  getAllGroups(): OperationResult<KdbxGroup[]>;
}
```

#### 方法详解

##### `searchEntries(criteria: SearchCriteria): OperationResult<SearchResult[]>`

根据搜索条件查找条目。

**参数**:
- `criteria`: 搜索条件对象

**返回值**: OperationResult\<SearchResult[]\> - 搜索结果列表

**示例**:
```typescript
const query = new KdbxQuery(database);
const criteria: SearchCriteria = {
  query: 'example.com',
  searchInTitles: true,
  searchInUsernames: true,
  searchInUrls: true,
  searchInNotes: false,
  caseSensitive: false,
  useRegex: false
};

const result = query.searchEntries(criteria);
if (result.success && result.data) {
  console.log(`找到 ${result.data.length} 个匹配条目`);
}
```

### KdbxGroupManager - 分组管理

管理数据库中的分组结构。

#### 类定义

```typescript
export class KdbxGroupManager {
  constructor(database: Kdbx);
  
  createGroup(parentGroupId: string, name: string): OperationResult<KdbxGroup>;
  updateGroup(group: KdbxGroup, name: string): OperationResult<void>;
  deleteGroup(group: KdbxGroup): OperationResult<void>;
  moveGroup(group: KdbxGroup, newParentId: string): OperationResult<void>;
  getGroupHierarchy(): OperationResult<GroupNode[]>;
}
```

## 📊 数据类型

### 基础类型

#### OperationResult\<T\>

所有操作的统一返回类型。

```typescript
export interface OperationResult<T> {
  success: boolean;
  data?: T;
  error?: string;
}
```

#### SearchCriteria

搜索条件配置。

```typescript
export interface SearchCriteria {
  query: string;                 // 搜索关键词
  searchInTitles: boolean;      // 是否搜索标题
  searchInUsernames: boolean;   // 是否搜索用户名
  searchInUrls: boolean;        // 是否搜索URL
  searchInNotes: boolean;       // 是否搜索备注
  caseSensitive: boolean;       // 是否区分大小写
  useRegex: boolean;           // 是否使用正则表达式
}
```

#### SearchResult

搜索结果项。

```typescript
export interface SearchResult {
  entry: KdbxEntry;            // 匹配的条目
  group: KdbxGroup;           // 条目所在分组
  matchedFields: string[];    // 匹配的字段名称
  relevanceScore: number;     // 相关性评分
}
```

### 模板类型

#### Template

模板接口定义。

```typescript
export interface Template {
  name: string;               // 模板名称
  description: string;        // 模板描述
  icon: string;              // 图标标识
  fields: TemplateField[];   // 字段定义
  validate(fields: Map<string, string>): ValidationResult;
}
```

#### TemplateField

模板字段定义。

```typescript
export interface TemplateField {
  key: string;               // 字段键名
  label: string;             // 显示标签
  type: FieldType;          // 字段类型
  required: boolean;        // 是否必填
  protected: boolean;       // 是否受保护
  placeholder?: string;     // 占位符文本
  validation?: string;      // 验证规则
}
```

#### FieldType

字段类型枚举。

```typescript
export enum FieldType {
  TEXT = 'text',
  PASSWORD = 'password',
  EMAIL = 'email',
  URL = 'url',
  NUMBER = 'number',
  DATE = 'date',
  TEXTAREA = 'textarea'
}
```

## ⚠️ 错误处理

### 错误类型

#### KdbxError

自定义错误类型。

```typescript
export class KdbxError extends Error {
  constructor(
    message: string,
    public code: string,
    public details?: any
  ) {
    super(message);
    this.name = 'KdbxError';
  }
}
```

### 常见错误码

| 错误码 | 说明 | 处理建议 |
|--------|------|----------|
| `INVALID_PASSWORD` | 密码错误 | 请检查密码是否正确 |
| `FILE_CORRUPTED` | 文件损坏 | 尝试使用备份文件 |
| `ENCRYPTION_FAILED` | 加密失败 | 检查系统加密支持 |
| `ENTRY_NOT_FOUND` | 条目不存在 | 确认条目ID是否正确 |
| `GROUP_NOT_FOUND` | 分组不存在 | 确认分组ID是否正确 |
| `PERMISSION_DENIED` | 权限不足 | 检查文件系统权限 |

### 错误处理示例

```typescript
try {
  const core = await KdbxCore.load(data, password);
} catch (error) {
  if (error instanceof KdbxError) {
    switch (error.code) {
      case 'INVALID_PASSWORD':
        console.error('密码错误，请重新输入');
        break;
      case 'FILE_CORRUPTED':
        console.error('文件已损坏，请检查文件完整性');
        break;
      default:
        console.error('操作失败:', error.message);
    }
  } else {
    console.error('未知错误:', error);
  }
}
```

## 💡 代码示例

### 完整的数据库操作流程

```typescript
import { 
  KdbxCore, 
  KdbxEntryManager, 
  KdbxQuery,
  LoginTemplate 
} from '@/lib/index';

async function completeExample() {
  try {
    // 1. 创建或加载数据库
    const core = await KdbxCore.create('mySecurePassword');
    const database = core.getDatabase();
    
    // 2. 初始化管理器
    const entryManager = new KdbxEntryManager(database);
    const query = new KdbxQuery(database);
    
    // 3. 获取默认分组
    const groupsResult = await query.getAllGroups();
    if (!groupsResult.success || !groupsResult.data?.length) {
      throw new Error('获取分组失败');
    }
    const defaultGroup = groupsResult.data[0];
    
    // 4. 创建新条目
    const createResult = entryManager.createEntry(
      defaultGroup.uuid.id, 
      LoginTemplate
    );
    
    if (!createResult.success || !createResult.data) {
      throw new Error('创建条目失败: ' + createResult.error);
    }
    
    // 5. 更新条目字段
    const fields = new Map([
      ['Title', 'Example Website'],
      ['UserName', 'user@example.com'],
      ['Password', 'securePassword123'],
      ['URL', 'https://example.com']
    ]);
    
    const updateResult = entryManager.updateEntry(createResult.data, fields);
    if (!updateResult.success) {
      throw new Error('更新条目失败: ' + updateResult.error);
    }
    
    // 6. 搜索条目
    const searchResult = query.searchEntries({
      query: 'example',
      searchInTitles: true,
      searchInUsernames: true,
      searchInUrls: true,
      searchInNotes: false,
      caseSensitive: false,
      useRegex: false
    });
    
    if (searchResult.success && searchResult.data) {
      console.log(`搜索到 ${searchResult.data.length} 个条目`);
    }
    
    // 7. 保存数据库
    const savedData = await core.save();
    console.log('数据库操作完成，数据已保存');
    
  } catch (error) {
    console.error('操作失败:', error);
  }
}
```

### 模板定义示例

```typescript
import { Template, TemplateField, FieldType } from '@/lib/index';

export const CustomTemplate: Template = {
  name: 'Custom Login',
  description: '自定义登录模板',
  icon: 'custom-icon',
  
  fields: [
    {
      key: 'Title',
      label: '网站名称',
      type: FieldType.TEXT,
      required: true,
      protected: false,
      placeholder: '请输入网站名称'
    },
    {
      key: 'UserName',
      label: '用户名',
      type: FieldType.EMAIL,
      required: true,
      protected: false,
      placeholder: 'user@example.com'
    },
    {
      key: 'Password',
      label: '密码',
      type: FieldType.PASSWORD,
      required: true,
      protected: true,
      placeholder: '请输入密码'
    },
    {
      key: 'TwoFactorCode',
      label: '双因子验证码',
      type: FieldType.TEXT,
      required: false,
      protected: true,
      placeholder: '6位验证码'
    }
  ],
  
  validate(fields: Map<string, string>) {
    const errors: string[] = [];
    
    // 验证必填字段
    if (!fields.get('Title')?.trim()) {
      errors.push('网站名称不能为空');
    }
    
    if (!fields.get('UserName')?.trim()) {
      errors.push('用户名不能为空');
    }
    
    if (!fields.get('Password')?.trim()) {
      errors.push('密码不能为空');
    }
    
    // 验证邮箱格式
    const email = fields.get('UserName');
    if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      errors.push('用户名格式不正确');
    }
    
    return {
      isValid: errors.length === 0,
      errors
    };
  }
};
```

## 🏆 最佳实践

### 1. 内存管理

```typescript
// 正确：及时清理敏感数据
async function handleSensitiveData() {
  let decryptedData: ArrayBuffer | null = null;
  
  try {
    decryptedData = await decryptData(encryptedData);
    // 使用解密后的数据
    processData(decryptedData);
  } finally {
    // 确保清理内存
    if (decryptedData) {
      secureZero(decryptedData);
      decryptedData = null;
    }
  }
}
```

### 2. 错误处理

```typescript
// 正确：具体的错误处理
async function robustDatabaseOperation() {
  try {
    const result = await entryManager.createEntry(groupId, template);
    
    if (!result.success) {
      // 处理业务逻辑错误
      handleBusinessError(result.error);
      return;
    }
    
    // 处理成功结果
    handleSuccess(result.data);
    
  } catch (error) {
    // 处理系统级错误
    if (error instanceof KdbxError) {
      handleKdbxError(error);
    } else {
      handleUnknownError(error);
    }
  }
}
```

### 3. 异步操作

```typescript
// 正确：使用async/await和Promise.all优化性能
async function efficientDataLoading() {
  try {
    // 并行执行不相关的操作
    const [entriesResult, groupsResult, starredResult] = await Promise.all([
      query.getAllEntries(),
      query.getAllGroups(),
      query.getStarredEntries()
    ]);
    
    // 处理结果
    if (entriesResult.success) {
      processEntries(entriesResult.data);
    }
    
    if (groupsResult.success) {
      processGroups(groupsResult.data);
    }
    
    if (starredResult.success) {
      processStarred(starredResult.data);
    }
    
  } catch (error) {
    console.error('数据加载失败:', error);
  }
}
```

### 4. 类型安全

```typescript
// 正确：使用类型保护和断言
function processEntry(entry: unknown): void {
  // 类型保护
  if (!isKdbxEntry(entry)) {
    throw new Error('无效的条目对象');
  }
  
  // 安全地访问属性
  const title = entry.fields.get('Title')?.getText() ?? '无标题';
  const username = entry.fields.get('UserName')?.getText() ?? '';
  
  console.log(`处理条目: ${title} (${username})`);
}

function isKdbxEntry(obj: unknown): obj is KdbxEntry {
  return obj instanceof KdbxEntry && 
         typeof obj.uuid === 'object' &&
         obj.fields instanceof Map;
}
```

### 5. 性能优化

```typescript
// 正确：使用缓存和分页
class OptimizedQuery {
  private cache = new Map<string, any>();
  
  async getEntriesWithPagination(
    page: number, 
    pageSize: number
  ): Promise<OperationResult<KdbxEntry[]>> {
    const cacheKey = `entries_${page}_${pageSize}`;
    
    // 检查缓存
    if (this.cache.has(cacheKey)) {
      return {
        success: true,
        data: this.cache.get(cacheKey)
      };
    }
    
    // 获取数据
    const allEntries = await this.query.getAllEntries();
    if (!allEntries.success || !allEntries.data) {
      return allEntries;
    }
    
    // 分页处理
    const startIndex = (page - 1) * pageSize;
    const paginatedEntries = allEntries.data.slice(
      startIndex, 
      startIndex + pageSize
    );
    
    // 缓存结果
    this.cache.set(cacheKey, paginatedEntries);
    
    return {
      success: true,
      data: paginatedEntries
    };
  }
}
```

---

**API使用愉快！** 🚀

> 本API文档持续更新，如有疑问请参考源码或联系开发团队。 