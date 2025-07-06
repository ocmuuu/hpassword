# hPassword 开发者指南

## 📖 目录

1. [开发环境搭建](#开发环境搭建)
2. [项目架构](#项目架构)
3. [核心模块](#核心模块)
4. [API文档](#api文档)
5. [开发规范](#开发规范)
6. [扩展开发](#扩展开发)
7. [调试与测试](#调试与测试)
8. [发布流程](#发布流程)

## 🛠️ 开发环境搭建

### 必要条件

- **操作系统**：Windows 10/11, macOS 10.15+, Ubuntu 18.04+
- **DevEco Studio**：5.0.3 及以上版本
- **HarmonyOS SDK**：5.0.5(17) 及以上版本
- **Node.js**：16.x 及以上版本（可选，用于构建工具）

### 环境配置

1. **安装DevEco Studio**
   ```bash
   # 下载并安装DevEco Studio
   # 配置HarmonyOS SDK路径
   # 设置模拟器或连接真机
   ```

2. **项目依赖**
   ```bash
   # 克隆项目
   git clone <repository-url>
   cd hPassword
   
   # 安装依赖
   hvigor clean
   hvigor sync
   ```

3. **IDE配置**
   - 配置TypeScript语言服务
   - 启用ArkTS语法高亮
   - 设置代码格式化规则

## 🏗️ 项目架构

### 整体架构

```
hPassword/
├── AppScope/              # 应用级配置
├── entry/                 # 主模块
│   ├── src/main/ets/     # 主要源码
│   │   ├── declarations/  # 类型声明
│   │   ├── lib/          # 核心库
│   │   ├── pages/        # 页面组件
│   │   ├── templates/    # 模板定义
│   │   ├── utils/        # 工具类
│   │   └── test/         # 测试文件
│   └── src/main/resources/ # 资源文件
└── docs/                  # 文档
```

### 架构层次

```
┌─────────────────────────────────────┐
│           UI Layer (ArkUI)          │
├─────────────────────────────────────┤
│        Business Logic Layer        │
├─────────────────────────────────────┤
│         Data Access Layer          │
├─────────────────────────────────────┤
│          Security Layer            │
├─────────────────────────────────────┤
│         Storage Layer              │
└─────────────────────────────────────┘
```

### 核心设计模式

1. **MVC架构**：页面-业务逻辑-数据分离
2. **工厂模式**：模板和加密器创建
3. **单例模式**：全局状态管理
4. **观察者模式**：响应式状态更新
5. **策略模式**：多种加密算法切换

## 🧱 核心模块

### 1. 安全模块 (lib/crypto/)

```typescript
// 加密引擎
export class CryptoEngine {
  static encrypt(data: ArrayBuffer, key: ArrayBuffer): Promise<ArrayBuffer>
  static decrypt(data: ArrayBuffer, key: ArrayBuffer): Promise<ArrayBuffer>
}

// 密钥派生
export class KeyEncryptorKdf {
  static deriveKey(password: string, salt: ArrayBuffer, rounds: number): Promise<ArrayBuffer>
}

// 受保护值
export class ProtectedValue {
  constructor(value: string | ArrayBuffer, protection: boolean = true)
  getText(): string
  getBinary(): ArrayBuffer
}
```

### 2. 数据格式模块 (lib/format/)

#### KeePass格式支持详情

hPassword实现了完整的KeePass数据库格式支持，包括：

- **版本支持**: 完全兼容KeePass 3.x和4.x格式
- **默认版本**: 创建新数据库时使用4.x格式
- **向后兼容**: 支持读取3.x格式数据库文件
- **特性支持**: 
  - KeePass 4.0: 基础功能完整支持
  - KeePass 4.1: 支持高级特性（自定义数据、前置父组等）

#### 核心格式类

```typescript
// KeePass数据库
export class Kdbx {
  static create(credentials: KdbxCredentials): Promise<Kdbx>
  static load(data: ArrayBuffer, credentials: KdbxCredentials): Promise<Kdbx>
  save(): Promise<ArrayBuffer>
  
  get groups(): KdbxGroup[]
  get entries(): KdbxEntry[]
  get meta(): KdbxMeta
  get versionMajor(): number  // 3 或 4
  get versionMinor(): number  // 次版本号
  
  // 版本控制
  setVersion(version: 3 | 4): void
  versionIsAtLeast(major: number, minor: number): boolean
  upgrade(): void
}

// 条目管理
export class KdbxEntry {
  fields: Map<string, ProtectedValue>
  times: KdbxTimes
  uuid: KdbxUuid
  
  // 字段操作
  getField(name: string): ProtectedValue | undefined
  setField(name: string, value: ProtectedValue): void
  deleteField(name: string): void
  
  // 4.1版本特性
  qualityCheck?: boolean
  previousParentGroup?: KdbxUuid
}

// 分组管理
export class KdbxGroup {
  name: string
  entries: KdbxEntry[]
  groups: KdbxGroup[]
  
  // 层次结构操作
  addEntry(entry: KdbxEntry): void
  removeEntry(entry: KdbxEntry): void
  addGroup(group: KdbxGroup): void
  removeGroup(group: KdbxGroup): void
  
  // 4.1版本特性
  tags?: string[]
  previousParentGroup?: KdbxUuid
}

// 数据库头部信息
export class KdbxHeader {
  versionMajor: number
  versionMinor: number
  
  // 版本常量
  static readonly DefaultFileVersionMajor: number = 4
  static readonly MinSupportedVersion: number = 3
  static readonly MaxSupportedVersion: number = 4
}
```

#### 技术栈依赖

hPassword基于kdbxweb库进行开发，并针对HarmonyOS进行了优化：

- **格式解析**: 基于kdbxweb的KDBX格式解析和生成
- **加密支持**: AES-256、ChaCha20、Salsa20
- **密钥派生**: 当前支持AES-KDF，Argon2在规划中
- **压缩支持**: 使用fflate库进行数据压缩
- **内存保护**: ProtectedValue机制保护敏感数据

### 3. 业务逻辑模块 (utils/)

```typescript
// 数据库核心管理
export class KdbxCore {
  private database: Kdbx
  private credentials: KdbxCredentials
  
  static create(password: string): Promise<KdbxCore>
  static load(data: ArrayBuffer, password: string): Promise<KdbxCore>
  
  getDatabase(): Kdbx
  save(): Promise<ArrayBuffer>
  changePassword(newPassword: string): Promise<void>
}

// 条目管理器
export class KdbxEntryManager {
  constructor(database: Kdbx)
  
  createEntry(groupId: string, template: Template): OperationResult<KdbxEntry>
  updateEntry(entry: KdbxEntry, fields: Map<string, string>): OperationResult<void>
  deleteEntry(entry: KdbxEntry): OperationResult<void>
  toggleEntryStarred(entry: KdbxEntry): OperationResult<void>
  isEntryStarred(entry: KdbxEntry): boolean
}

// 查询管理器
export class KdbxQuery {
  constructor(database: Kdbx)
  
  getAllEntries(): OperationResult<KdbxEntry[]>
  getEntriesByGroup(groupId: string): OperationResult<KdbxEntry[]>
  getStarredEntries(): OperationResult<KdbxEntry[]>
  searchEntries(criteria: SearchCriteria): OperationResult<SearchResult[]>
  findEntryById(id: string): OperationResult<KdbxEntry>
}
```

### 4. 模板系统 (templates/)

```typescript
// 模板接口
export interface Template {
  name: string
  description: string
  icon: string
  fields: TemplateField[]
  validate(fields: Map<string, string>): ValidationResult
}

// 模板字段
export interface TemplateField {
  key: string
  label: string
  type: FieldType
  required: boolean
  protected: boolean
  placeholder?: string
  validation?: string
}

// 字段类型
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

## 📚 API文档

### 核心API

#### KdbxCore API

```typescript
// 创建新数据库
KdbxCore.create(password: string): Promise<KdbxCore>

// 加载现有数据库
KdbxCore.load(data: ArrayBuffer, password: string): Promise<KdbxCore>

// 保存数据库
save(): Promise<ArrayBuffer>

// 更改密码
changePassword(newPassword: string): Promise<void>

// 获取数据库实例
getDatabase(): Kdbx
```

#### KdbxEntryManager API

```typescript
// 创建条目
createEntry(groupId: string, template: Template): OperationResult<KdbxEntry>

// 更新条目
updateEntry(entry: KdbxEntry, fields: Map<string, string>): OperationResult<void>

// 删除条目
deleteEntry(entry: KdbxEntry): OperationResult<void>

// 切换收藏状态
toggleEntryStarred(entry: KdbxEntry): OperationResult<void>

// 检查是否收藏
isEntryStarred(entry: KdbxEntry): boolean
```

#### KdbxQuery API

```typescript
// 获取所有条目
getAllEntries(): OperationResult<KdbxEntry[]>

// 按分组获取条目
getEntriesByGroup(groupId: string): OperationResult<KdbxEntry[]>

// 获取收藏条目
getStarredEntries(): OperationResult<KdbxEntry[]>

// 搜索条目
searchEntries(criteria: SearchCriteria): OperationResult<SearchResult[]>

// 按ID查找条目
findEntryById(id: string): OperationResult<KdbxEntry>
```

### 数据类型

```typescript
// 操作结果
export interface OperationResult<T> {
  success: boolean
  data?: T
  error?: string
}

// 搜索条件
export interface SearchCriteria {
  query: string
  searchInTitles: boolean
  searchInUsernames: boolean
  searchInUrls: boolean
  searchInNotes: boolean
  caseSensitive: boolean
  useRegex: boolean
}

// 搜索结果
export interface SearchResult {
  entry: KdbxEntry
  group: KdbxGroup
  matchedFields: string[]
  relevanceScore: number
}
```

## 📝 开发规范

### 代码风格

1. **TypeScript配置**
   ```json
   {
     "compilerOptions": {
       "strict": true,
       "noImplicitAny": true,
       "noImplicitReturns": true,
       "noImplicitThis": true
     }
   }
   ```

2. **命名约定**
   - 类名：PascalCase (如：`KdbxCore`)
   - 方法名：camelCase (如：`createEntry`)
   - 常量：UPPER_SNAKE_CASE (如：`DEFAULT_TIMEOUT`)
   - 接口：PascalCase + Interface后缀 (如：`TemplateInterface`)

3. **文件组织**
   - 一个文件一个类
   - 相关功能分组到同一目录
   - 导出使用index.ts统一管理

### 安全编码规范

1. **敏感数据处理**
   ```typescript
   // 正确：使用ProtectedValue
   const password = new ProtectedValue(userInput, true);
   
   // 错误：直接使用字符串
   const password = userInput;
   ```

2. **内存管理**
   ```typescript
   // 正确：及时清理敏感数据
   try {
     const decryptedData = await decrypt(data, key);
     // 使用数据
   } finally {
     // 清理内存
     secureZero(decryptedData);
   }
   ```

3. **错误处理**
   ```typescript
   // 正确：不暴露敏感信息
   try {
     await decryptData(data, key);
   } catch (error) {
     throw new KdbxError('解密失败', 'DECRYPT_ERROR');
   }
   ```

### ArkTS规范

1. **类型声明**
   ```typescript
   // 正确：明确类型
   @State private entryItems: EntryItem[] = [];
   
   // 错误：使用any
   @State private entryItems: any[] = [];
   ```

2. **状态管理**
   ```typescript
   // 正确：使用@State装饰器
   @State private isLoading: boolean = false;
   
   // 正确：使用@Observed/@ObjectLink
   @ObjectLink private entry: ObservedEntry;
   ```

3. **组件通信**
   ```typescript
   // 正确：使用@Prop/@Link
   @Prop entry: EntryItem;
   @Link isSelected: boolean;
   
   // 正确：使用AppStorage
   AppStorage.setOrCreate('selectedEntry', entry);
   ```

## 🔧 扩展开发

### 自定义模板

1. **创建模板类**
   ```typescript
   export class CustomTemplate implements Template {
     name = 'Custom Template';
     description = 'Custom template description';
     icon = 'custom-icon';
     
     fields: TemplateField[] = [
       {
         key: 'title',
         label: '标题',
         type: FieldType.TEXT,
         required: true,
         protected: false
       },
       {
         key: 'secret',
         label: '密钥',
         type: FieldType.PASSWORD,
         required: true,
         protected: true
       }
     ];
     
     validate(fields: Map<string, string>): ValidationResult {
       // 自定义验证逻辑
       return { isValid: true };
     }
   }
   ```

2. **注册模板**
   ```typescript
   // 在templates/index.ts中添加
   export { CustomTemplate } from './CustomTemplate';
   ```

### 自定义加密器

1. **实现加密接口**
   ```typescript
   export class CustomEncryptor implements Encryptor {
     async encrypt(data: ArrayBuffer, key: ArrayBuffer): Promise<ArrayBuffer> {
       // 自定义加密逻辑
     }
     
     async decrypt(data: ArrayBuffer, key: ArrayBuffer): Promise<ArrayBuffer> {
       // 自定义解密逻辑
     }
   }
   ```

2. **注册加密器**
   ```typescript
   CryptoEngine.registerEncryptor('custom', new CustomEncryptor());
   ```

## 🧪 调试与测试

### 单元测试

```typescript
// 测试示例
describe('KdbxEntryManager', () => {
  let database: Kdbx;
  let manager: KdbxEntryManager;
  
  beforeEach(async () => {
    database = await Kdbx.create(credentials);
    manager = new KdbxEntryManager(database);
  });
  
  it('should create entry successfully', () => {
    const result = manager.createEntry(groupId, template);
    expect(result.success).toBe(true);
    expect(result.data).toBeDefined();
  });
});
```

### 集成测试

```typescript
// 数据库CRUD测试
export async function runDatabaseCRUDTest(
  context: Context,
  kdbxCore: KdbxCore,
  password: string
): Promise<boolean> {
  try {
    // 创建测试
    const createResult = await testCreateEntry(kdbxCore);
    if (!createResult) return false;
    
    // 读取测试
    const readResult = await testReadEntry(kdbxCore);
    if (!readResult) return false;
    
    // 更新测试
    const updateResult = await testUpdateEntry(kdbxCore);
    if (!updateResult) return false;
    
    // 删除测试
    const deleteResult = await testDeleteEntry(kdbxCore);
    if (!deleteResult) return false;
    
    return true;
  } catch (error) {
    console.error('CRUD测试失败:', error);
    return false;
  }
}
```

### 性能测试

```typescript
// 性能测试工具
export class PerformanceProfiler {
  private startTime: number = 0;
  
  start(): void {
    this.startTime = Date.now();
  }
  
  end(operation: string): void {
    const duration = Date.now() - this.startTime;
    console.log(`${operation} 耗时: ${duration}ms`);
  }
}
```

## 📦 发布流程

### 构建配置

1. **构建脚本**
   ```bash
   # 清理构建
   hvigor clean
   
   # 构建HAP包
   hvigor assembleHap
   
   # 构建APP包
   hvigor assembleApp
   ```

2. **版本管理**
   ```json
   // entry/src/main/module.json5
   {
     "module": {
       "name": "entry",
       "type": "entry",
       "description": "$string:module_desc",
       "mainElement": "EntryAbility",
       "deviceTypes": ["phone", "tablet"],
       "deliveryWithInstall": true,
       "installationFree": false,
       "pages": "$profile:main_pages",
       "abilities": [...],
       "requestPermissions": [...]
     }
   }
   ```

### 发布检查清单

- [ ] 代码审查通过
- [ ] 单元测试覆盖率 > 80%
- [ ] 集成测试通过
- [ ] 性能测试通过
- [ ] 安全审计通过
- [ ] 文档更新完成
- [ ] 版本号更新
- [ ] 发布说明准备
- [ ] 签名配置正确

### 部署流程

1. **构建发布包**
   ```bash
   hvigor --mode release assembleHap
   ```

2. **签名配置**
   ```bash
   # 配置签名证书
   # 生成发布包
   ```

3. **发布到应用商店**
   - 上传HAP包到华为应用市场
   - 填写应用信息和发布说明
   - 提交审核

---

**开发愉快！** 🚀

> 本指南持续更新，请关注最新开发规范和最佳实践。 