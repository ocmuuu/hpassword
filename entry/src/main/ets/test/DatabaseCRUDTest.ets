import { hilog } from '@kit.PerformanceAnalysisKit';
import { Context } from '@kit.AbilityKit';
import { KdbxCore, KdbxCoreManager } from '../utils/KdbxCore';
import { KdbxGroupManager } from '../utils/KdbxGroupManager';
import { KdbxEntryManager } from '../utils/KdbxEntryManager';
import { KdbxQuery } from '../utils/KdbxQuery';
import { DefaultDatabase } from '../utils/DefaultDatabase';
import { KdbxGroup, KdbxEntry, ProtectedValue } from '../lib';
import { ALL_TEMPLATES, CategoryTemplate, FieldSpec } from '../templates';
import { 
  GroupCreateParams, 
  EntryCreateParams, 
  GroupUpdateParams, 
  EntryUpdateParams,
  DatabaseEventType,
  OperationResult,
  EntryInfo
} from '../utils/KdbxTypes';
import { getEntryDisplayText } from '../utils/KdbxUtils';

const TAG = 'DatabaseCRUDTest';

/**
 * 数据库增删改查完整测试
 */
export class DatabaseCRUDTest {
  private kdbxCore: KdbxCore | null = null;
  private groupManager: KdbxGroupManager | null = null;
  private entryManager: KdbxEntryManager | null = null;
  private kdbxQuery: KdbxQuery | null = null;
  private testResults: string[] = [];
  private databasePassword: string = '';

  /**
   * 初始化测试环境
   */
  async initializeTest(context: Context, existingKdbxCore?: KdbxCore, password?: string): Promise<boolean> {
    try {
      hilog.info(0, TAG, '开始初始化测试环境...');
      
      // 设置数据库密码
      this.databasePassword = password || 'test123456';
      
      if (existingKdbxCore) {
        // 使用已存在的KdbxCore实例
        this.kdbxCore = existingKdbxCore;
        hilog.info(0, TAG, '使用已存在的数据库实例');
      } else {
        // 设置默认数据库管理器的上下文
        const defaultDb = DefaultDatabase.getInstance();
        defaultDb.setContext(context);
        
        // 检查默认数据库是否存在，如果存在则删除
        if (await defaultDb.exists()) {
          await defaultDb.delete();
          hilog.info(0, TAG, '删除已存在的测试数据库');
        }
        
        // 创建新的测试数据库
        const createResult = await defaultDb.create(this.databasePassword);
        if (!createResult.success) {
          throw new Error(`创建测试数据库失败: ${createResult.error}`);
        }
        
        // 打开数据库
        const openResult = await defaultDb.open(this.databasePassword);
        if (!openResult.success || !openResult.data) {
          throw new Error(`打开测试数据库失败: ${openResult.error}`);
        }
        
        this.kdbxCore = openResult.data;
      }
      
      const database = this.kdbxCore.getDatabase();
      if (!database) {
        throw new Error('无法获取数据库实例');
      }
      
      // 初始化管理器
      this.groupManager = new KdbxGroupManager(database, this.onDatabaseEvent.bind(this));
      this.entryManager = new KdbxEntryManager(database, this.onDatabaseEvent.bind(this));
      this.kdbxQuery = new KdbxQuery(database);
      
      hilog.info(0, TAG, '测试环境初始化成功');
      return true;
      
    } catch (error) {
      hilog.error(0, TAG, '初始化测试环境失败: %{public}s', (error as Error).message);
      return false;
    }
  }

  /**
   * 数据库事件监听器
   */
  private onDatabaseEvent(eventType: DatabaseEventType, data?: Record<string, Object>): void {
    hilog.info(0, TAG, '数据库事件: %{public}s', eventType);
  }

  /**
   * 获取条目标题的辅助方法（避免使用 `in`、类型守卫与 call/apply）
   */
  private getEntryTitle(entry: KdbxEntry | EntryInfo): string {
    const maybeInfo = entry as EntryInfo;
    if (typeof maybeInfo.title === 'string') {
      // EntryInfo 情况
      return maybeInfo.title.length > 0 ? maybeInfo.title : '未命名条目';
    }

    // 回退处理 KdbxEntry
    return getEntryDisplayText(entry as KdbxEntry, 'Title') || '未命名条目';
  }

  /**
   * 根据 templates 初始化分类分组及示例条目
   */
  private initializeTemplatesData(): void {
    if (!this.groupManager || !this.entryManager || !this.kdbxCore) {
      throw new Error('管理器未初始化');
    }

    const database = this.kdbxCore.getDatabase();
    if (!database) {
      throw new Error('数据库未加载');
    }

    const rootGroup = database.getDefaultGroup();
    if (!rootGroup) {
      throw new Error('根组不存在');
    }

    // 遍历所有模板
    for (let i = 0; i < ALL_TEMPLATES.length; i++) {
      const tpl: CategoryTemplate = ALL_TEMPLATES[i];

      // 创建或获取分组
      const groupResult = this.groupManager.createGroup({
        name: tpl.name,
        notes: tpl.desc,
        parentGroup: rootGroup
      });

      const targetGroup = groupResult.success && groupResult.data ? groupResult.data : null;
      if (!targetGroup) {
        hilog.warn(0, TAG, '创建分组失败或已存在: %{public}s', tpl.name);
        continue;
      }

      // 遍历示例条目（最多2条）
      const samples = tpl.samples.slice(0, 2);
      for (let j = 0; j < samples.length; j++) {
        const sample = samples[j];

        // 构造条目参数
        const createParams: EntryCreateParams = {
          title: sample['Title'] || `${tpl.name} 示例 ${j + 1}`,
          parentGroup: targetGroup,
          customFields: new Map()
        } as EntryCreateParams;

        // 根据模板字段映射到 EntryCreateParams
        for (let k = 0; k < tpl.fields.length; k++) {
          const field: FieldSpec = tpl.fields[k];
          const key = field.key;
          const maybeVal = (sample as Record<string, string>)[key];
          if (maybeVal === undefined) {
            continue;
          }
          const value = maybeVal;

          switch (key) {
            case 'UserName':
              createParams.username = value as string;
              break;
            case 'Password':
              createParams.password = value as string;
              break;
            case 'URL':
              createParams.url = value as string;
              break;
            case 'Notes':
              createParams.notes = value as string;
              break;
            case 'Title':
              // 已处理
              break;
            default:
              // 其他字段放入 customFields，并考虑受保护标记
              if (field.protected) {
                createParams.customFields?.set(key, ProtectedValue.fromString(value as string));
              } else {
                createParams.customFields?.set(key, value as string);
              }
              break;
          }
        }

        const entryResult = this.entryManager.createEntry(createParams);
        if (entryResult.success) {
          this.testResults.push(`✓ 初始化条目: ${tpl.name} - ${createParams.title}`);
        } else {
          hilog.warn(0, TAG, '创建示例条目失败: %{public}s - %{public}s', tpl.name, entryResult.error || 'unknown');
        }
      }
    }

    // 初始化后立即标记保存
    hilog.info(0, TAG, '已根据模板初始化分类与示例条目');
  }

  /**
   * 清理非模板分组及条目（移动至回收站或直接删除）
   */
  private cleanupNonTemplateData(): void {
    if (!this.groupManager || !this.entryManager || !this.kdbxCore || !this.kdbxQuery) {
      return;
    }

    const templateNames: string[] = ALL_TEMPLATES.map(t => t.name);

    // 定义保留的分组（测试后只保留这些分组的条目）
    const preservedGroups: string[] = [
      '登录密码',
      '安全笔记',
      '银行账户',
      '支付账户',
      '邮箱账户',
      '会员卡',
      '会员订阅'
    ];

    // 建立模板 -> 允许条目标题集合（仅对保留的分组）
    const templateTitleMap = new Map<string, Set<string>>();
    for (let i = 0; i < ALL_TEMPLATES.length; i++) {
      const tpl = ALL_TEMPLATES[i];
      
      // 只对保留的分组保留示例条目
      if (preservedGroups.includes(tpl.name)) {
        const titles = new Set<string>();
        for (let j = 0; j < tpl.samples.length; j++) {
          const t = tpl.samples[j]['Title'];
          if (typeof t === 'string') {
            titles.add(t);
          }
        }
        templateTitleMap.set(tpl.name, titles);
      }
    }

    const groupsResult = this.kdbxQuery.getAllGroups();
    if (!groupsResult.success || !groupsResult.data) {
      return;
    }

    for (const group of groupsResult.data) {
      const gName: string = group.name || '';

      if (!templateNames.includes(gName)) {
        // 非模板分组 → 递归删除（软删除）
        this.groupManager!.deleteGroupRecursive(group);
        continue;
      }

      // 模板分组：检查条目
      const allowedTitles = templateTitleMap.get(gName) || new Set<string>();
      const entriesResult = this.entryManager.getEntriesInGroup(group.uuid.id);
      if (!entriesResult.success || !entriesResult.data) {
        continue;
      }

      for (const info of entriesResult.data) {
        const title = this.getEntryTitle(info);
        
        // 对于保留的分组，只保留示例条目；对于其他分组，删除所有条目
        if (preservedGroups.includes(gName)) {
          // 保留的分组：只保留示例条目
          if (allowedTitles.has(title)) {
            continue;
          }
        }
        
        // 删除非示例条目或非保留分组的所有条目
        const entryLookup = this.kdbxQuery.findEntryById(info.id);
        if (entryLookup.success && entryLookup.data) {
          this.entryManager!.deleteEntry(entryLookup.data);
        }
      }
    }

    this.testResults.push(`✓ 测试数据清理完成，保留分组: ${preservedGroups.join(', ')}`);
  }

  /**
   * 运行完整的CRUD测试
   */
  async runFullCRUDTest(): Promise<boolean> {
    try {
      hilog.info(0, TAG, '开始运行完整的CRUD测试...');
      this.testResults = [];
      
      // 初始状态检查 - 详细检查数据库结构
      await this.logDatabaseState('测试开始');

      // 0. 初始化模板分类及示例数据
      this.initializeTemplatesData();
      await this.logDatabaseState('模板数据初始化后');
      
      // 1. 测试分组CRUD
      await this.testGroupCRUD();
      await this.logDatabaseState('分组CRUD测试后');
      
      // 2. 测试条目CRUD
      await this.testEntryCRUD();
      await this.logDatabaseState('条目CRUD测试后');
      
      // 3. 测试复合操作
      await this.testComplexOperations();
      await this.logDatabaseState('复合操作测试后');

      // 3.5 清理非模板数据
      this.cleanupNonTemplateData();
      await this.logDatabaseState('清理非模板数据后');
      
      // 4. 测试数据完整性
      await this.testDataIntegrity();
      await this.logDatabaseState('数据完整性测试后');
      
      // 5. 测试数据持久化 - 关闭重新打开验证数据一致性
      await this.testDataPersistence();
      
      // 打印测试结果
      this.printTestResults();
      
      hilog.info(0, TAG, '完整的CRUD测试完成');
      return true;
      
    } catch (error) {
      hilog.error(0, TAG, 'CRUD测试失败: %{public}s', (error as Error).message);
      return false;
    }
  }

  /**
   * 测试分组CRUD操作
   */
  private async testGroupCRUD(): Promise<void> {
    hilog.info(0, TAG, '开始测试分组CRUD操作...');
    
    if (!this.groupManager || !this.kdbxCore) {
      throw new Error('管理器未初始化');
    }

    const database = this.kdbxCore.getDatabase();
    if (!database) {
      throw new Error('数据库未加载');
    }

    const rootGroup = database.getDefaultGroup();
    if (!rootGroup) {
      throw new Error('根组不存在');
    }

    // 1. 创建分组（增）
    hilog.info(0, TAG, '测试创建分组...');
    const createParams: GroupCreateParams = {
      name: '测试分组',
      notes: '存储工作相关的账号信息',
      parentGroup: rootGroup
    };
    
    const createResult = this.groupManager.createGroup(createParams);
    if (!createResult.success || !createResult.data) {
      throw new Error(`创建分组失败: ${createResult.error}`);
    }
    
    const workGroup = createResult.data;
    this.testResults.push('✓ 创建分组成功');
    
    // 创建子分组
    const subGroupParams: GroupCreateParams = {
      name: '子测试分组',
      notes: '开发相关的工具账号',
      parentGroup: workGroup
    };
    
    const subGroupResult = this.groupManager.createGroup(subGroupParams);
    if (!subGroupResult.success || !subGroupResult.data) {
      throw new Error(`创建子分组失败: ${subGroupResult.error}`);
    }
    
    const devGroup = subGroupResult.data;
    this.testResults.push('✓ 创建子分组成功');
    
    // 2. 查询分组（查）
    hilog.info(0, TAG, '测试查询分组...');
    const groupsResult = this.kdbxQuery!.getAllGroups();
    if (!groupsResult.success || !groupsResult.data) {
      throw new Error(`查询分组失败: ${groupsResult.error}`);
    }
    
    const groups: KdbxGroup[] = groupsResult.data;
    hilog.info(0, TAG, '找到 %{public}d 个分组', groups.length);
    this.testResults.push(`✓ 查询分组成功，共找到 ${groups.length} 个分组`);
    
    // 3. 更新分组（改）
    hilog.info(0, TAG, '测试更新分组...');
    const updateParams: GroupUpdateParams = {
      name: '测试分组 (已更新)',
      notes: '更新后的测试分组描述'
    };
    
    const updateResult = this.groupManager.updateGroup(workGroup, updateParams);
    if (!updateResult.success) {
      throw new Error(`更新分组失败: ${updateResult.error}`);
    }
    
    this.testResults.push('✓ 更新分组成功');
    
    // 4. 移动分组
    hilog.info(0, TAG, '测试移动分组...');
    const moveResult = this.groupManager.moveGroup(devGroup, rootGroup);
    if (!moveResult.success) {
      throw new Error(`移动分组失败: ${moveResult.error}`);
    }
    
    this.testResults.push('✓ 移动分组成功');
    
    // 5. 删除分组（删）
    hilog.info(0, TAG, '测试删除分组...');
    const deleteResult = this.groupManager.deleteGroup(devGroup);
    if (!deleteResult.success) {
      throw new Error(`删除分组失败: ${deleteResult.error}`);
    }
    
    this.testResults.push('✓ 删除分组成功');

    // 清理：删除主测试分组，确保不留残余
    const cleanupResult = this.groupManager!.deleteGroup(workGroup);
    if (cleanupResult.success) {
      this.testResults.push('✓ 清理测试分组成功');
    }
    
    hilog.info(0, TAG, '分组CRUD操作测试完成');
  }

  /**
   * 测试条目CRUD操作
   */
  private async testEntryCRUD(): Promise<void> {
    hilog.info(0, TAG, '开始测试条目CRUD操作...');
    
    if (!this.entryManager || !this.kdbxCore) {
      throw new Error('管理器未初始化');
    }

    const database = this.kdbxCore.getDatabase();
    if (!database) {
      throw new Error('数据库未加载');
    }

    const rootGroup = database.getDefaultGroup();
    if (!rootGroup) {
      throw new Error('根组不存在');
    }

    // 1. 创建条目（增）
    hilog.info(0, TAG, '测试创建条目...');
    const createParams: EntryCreateParams = {
      title: '测试邮箱',
      username: 'test@example.com',
      password: 'password123',
      url: 'https://mail.example.com',
      notes: '这是一个测试邮箱账号',
      parentGroup: rootGroup
    };
    
    const createResult = this.entryManager.createEntry(createParams);
    if (!createResult.success || !createResult.data) {
      throw new Error(`创建条目失败: ${createResult.error}`);
    }
    
    const testEntry = createResult.data;
    this.testResults.push('✓ 创建条目成功');
    
    // 创建另一个条目
    const createParams2: EntryCreateParams = {
      title: '测试数据库',
      username: 'admin',
      password: 'dbpass456',
      url: 'http://localhost:3306',
      notes: '测试数据库连接信息',
      parentGroup: rootGroup
    };
    
    const createResult2 = this.entryManager.createEntry(createParams2);
    if (!createResult2.success || !createResult2.data) {
      throw new Error(`创建第二个条目失败: ${createResult2.error}`);
    }
    
    const testEntry2 = createResult2.data;
    this.testResults.push('✓ 创建第二个条目成功');
    
    // 2. 查询条目（查）
    hilog.info(0, TAG, '测试查询条目...');
    const entriesResult = this.entryManager.getEntriesInGroup(rootGroup.uuid.id);
    if (!entriesResult.success || !entriesResult.data) {
      throw new Error(`查询条目失败: ${entriesResult.error}`);
    }
    
    const entries = entriesResult.data;
    hilog.info(0, TAG, '找到 %{public}d 个条目', entries.length);
    this.testResults.push(`✓ 查询条目成功，共找到 ${entries.length} 个条目`);
    
    // 3. 更新条目（改）
    hilog.info(0, TAG, '测试更新条目...');
    const updateParams: EntryUpdateParams = {
      title: '测试邮箱 (已更新)',
      username: 'updated@example.com',
      password: 'newpassword789',
      notes: '更新后的邮箱账号信息'
    };
    
    const updateResult = this.entryManager.updateEntry(testEntry, updateParams);
    if (!updateResult.success) {
      throw new Error(`更新条目失败: ${updateResult.error}`);
    }
    
    this.testResults.push('✓ 更新条目成功');
    
    // 4. 移动条目
    hilog.info(0, TAG, '测试移动条目...');
    // 首先创建一个目标分组
    const targetGroupParams: GroupCreateParams = {
      name: '临时分组',
      notes: '个人使用的账号',
      parentGroup: rootGroup
    };
    
    const targetGroupResult = this.groupManager!.createGroup(targetGroupParams);
    if (!targetGroupResult.success || !targetGroupResult.data) {
      throw new Error(`创建目标分组失败: ${targetGroupResult.error}`);
    }
    
    const targetGroup = targetGroupResult.data;
    
    const moveResult = this.entryManager.moveEntry(testEntry2, targetGroup);
    if (!moveResult.success) {
      throw new Error(`移动条目失败: ${moveResult.error}`);
    }
    
    this.testResults.push('✓ 移动条目成功');
    
    // 5. 删除条目（删）
    hilog.info(0, TAG, '测试删除条目...');
    const deleteResult = this.entryManager.deleteEntry(testEntry2);
    if (!deleteResult.success) {
      throw new Error(`删除条目失败: ${deleteResult.error}`);
    }
    
    this.testResults.push('✓ 删除条目成功');

    // 清理：删除最初创建的条目和临时分组
    const deleteEntry1 = this.entryManager!.deleteEntry(testEntry);
    if (deleteEntry1.success) {
      this.testResults.push('✓ 清理测试条目成功');
    }

    const deleteTempGroup = this.groupManager!.deleteGroup(targetGroup);
    if (deleteTempGroup.success) {
      this.testResults.push('✓ 清理临时分组成功');
    }
    
    hilog.info(0, TAG, '条目CRUD操作测试完成');
  }

  /**
   * 测试复合操作
   */
  private async testComplexOperations(): Promise<void> {
    hilog.info(0, TAG, '开始测试复合操作...');
    
    if (!this.groupManager || !this.entryManager || !this.kdbxCore) {
      throw new Error('管理器未初始化');
    }

    const database = this.kdbxCore.getDatabase();
    if (!database) {
      throw new Error('数据库未加载');
    }

    const rootGroup = database.getDefaultGroup();
    if (!rootGroup) {
      throw new Error('根组不存在');
    }

    // 1. 批量创建分组和条目
    hilog.info(0, TAG, '测试批量创建...');
    
    const categories: string[] = ['批量测试组1', '批量测试组2', '批量测试组3', '批量测试组4'];
    const createdGroups: KdbxGroup[] = [];
    
    for (const category of categories) {
      const groupParams: GroupCreateParams = {
        name: category,
        notes: `${category}相关账号`,
        parentGroup: rootGroup
      };
      
      const groupResult = this.groupManager.createGroup(groupParams);
      if (!groupResult.success || !groupResult.data) {
        throw new Error(`创建分组 ${category} 失败: ${groupResult.error}`);
      }
      
      createdGroups.push(groupResult.data);
      
      // 为每个分组创建2个条目
      for (let i = 1; i <= 2; i++) {
        const entryParams: EntryCreateParams = {
          title: `${category} 账号 ${i}`,
          username: `user${i}@${category.toLowerCase()}.com`,
          password: `password${i}${category.length}`,
          url: `https://www.${category.toLowerCase()}${i}.com`,
          notes: `${category} 第${i}个账号`,
          parentGroup: groupResult.data
        };
        
        const entryResult = this.entryManager.createEntry(entryParams);
        if (!entryResult.success) {
          throw new Error(`创建条目 ${entryParams.title} 失败: ${entryResult.error}`);
        }
      }
    }
    
    this.testResults.push(`✓ 批量创建成功：${categories.length} 个分组，每个分组 2 个条目`);
    
    // 2. 测试递归删除
    hilog.info(0, TAG, '测试递归删除...');
    const deleteTarget: KdbxGroup = createdGroups[0]; // 删除第一个分组
    const deleteResult = this.groupManager!.deleteGroupRecursive(deleteTarget);
    if (!deleteResult.success) {
      throw new Error(`递归删除失败: ${deleteResult.error}`);
    }
    
    this.testResults.push('✓ 递归删除成功');

    // 工具函数：判断名称是否属于模板分类
    const isTemplateGroup = (name: string): boolean => {
      for (let m = 0; m < ALL_TEMPLATES.length; m++) {
        if (ALL_TEMPLATES[m].name === name) {
          return true;
        }
      }
      return false;
    };

    // 清理：删除其余批量创建的分组
    for (let i = 1; i < createdGroups.length; i++) {
      const g = createdGroups[i];
      if (isTemplateGroup(g.name || '')) {
        // 属于模板分类则保留
        continue;
      }
      this.groupManager!.deleteGroup(g);
    }
    this.testResults.push('✓ 清理批量创建分组成功');
    
    hilog.info(0, TAG, '复合操作测试完成');
  }

  /**
   * 测试数据完整性
   */
  private async testDataIntegrity(): Promise<void> {
    hilog.info(0, TAG, '开始测试数据完整性...');
    
    if (!this.groupManager || !this.entryManager || !this.kdbxCore) {
      throw new Error('管理器未初始化');
    }

    const database = this.kdbxCore.getDatabase();
    if (!database) {
      throw new Error('数据库未加载');
    }

    const rootGroup = database.getDefaultGroup();
    if (!rootGroup) {
      throw new Error('根组不存在');
    }

    // 1. 统计数据
    const groupsResult = this.kdbxQuery!.getAllGroups();
    if (!groupsResult.success || !groupsResult.data) {
      throw new Error(`获取分组列表失败: ${groupsResult.error}`);
    }
    
    const totalGroups: number = groupsResult.data.length;
    let totalEntries: number = 0;
    
    // 计算总条目数
    for (const group of groupsResult.data) {
      const entriesResult = this.entryManager.getEntriesInGroup(group.uuid.id);
      if (entriesResult.success && entriesResult.data) {
        totalEntries += entriesResult.data.length;
      }
    }
    
    hilog.info(0, TAG, '数据统计: %{public}d 个分组, %{public}d 个条目', totalGroups, totalEntries);
    this.testResults.push(`✓ 数据完整性检查通过：${totalGroups} 个分组，${totalEntries} 个条目`);
    
    // 2. 验证数据库完整性（通过检查数据库是否正常加载）
    if (this.kdbxCore.isLoaded_()) {
      this.testResults.push('✓ 数据库完整性验证通过');
    } else {
      throw new Error('数据库未正常加载，完整性验证失败');
    }
    
    hilog.info(0, TAG, '数据完整性测试完成');
  }

  /**
   * 测试数据持久化 - 保存关闭重新打开验证数据一致性
   */
  private async testDataPersistence(): Promise<void> {
    hilog.info(0, TAG, '开始测试数据持久化...');
    
    if (!this.kdbxCore || !this.kdbxQuery) {
      throw new Error('核心组件未初始化');
    }

    // 1. 记录保存前的数据状态 - 重新统计确保准确性
    const beforeGroups = this.kdbxQuery.getAllGroups();
    if (!beforeGroups.success || !beforeGroups.data) {
      throw new Error(`获取保存前分组数据失败: ${beforeGroups.error}`);
    }
    
    const beforeGroupsCount = beforeGroups.data.length;
    let beforeEntriesCount = 0;
    const beforeEntriesMap = new Map<string, number>(); // groupId -> entryCount
    const beforeGroupDetails: string[] = [];
    
    // 统计每个分组的条目数 - 增加详细日志
    for (const group of beforeGroups.data) {
      const entriesResult = this.entryManager!.getEntriesInGroup(group.uuid.id);
      if (entriesResult.success && entriesResult.data) {
        const count = entriesResult.data.length;
        beforeEntriesCount += count;
        beforeEntriesMap.set(group.uuid.id, count);
        
        const groupInfo = `${group.name || '未命名'}(${count}个条目)`;
        beforeGroupDetails.push(groupInfo);
      }
    }
    
    hilog.info(0, TAG, '保存前数据统计: %{public}d 个分组, %{public}d 个条目', beforeGroupsCount, beforeEntriesCount);
    hilog.info(0, TAG, '分组详情: %{public}s', beforeGroupDetails.join(', '));
    
    // 2. 保存并关闭数据库
    const defaultDb = DefaultDatabase.getInstance();
    const saveResult = await defaultDb.saveDatabase(this.kdbxCore);
    if (!saveResult.success) {
      throw new Error(`最终保存数据库失败: ${saveResult.error}`);
    }
    
    hilog.info(0, TAG, '数据库已保存，准备关闭并重新打开...');
    
    // 验证文件确实存在并且有内容
    const existsCheck = await defaultDb.exists();
    if (!existsCheck) {
      throw new Error('保存验证失败：数据库文件不存在');
    }
    
    // 3. 清理当前数据库连接
    const originalKdbxCore = this.kdbxCore; // 保存原始引用
    // 清理全局引用，避免UI继续使用旧实例
    KdbxCoreManager.getInstance().clearCurrentKdbxCore();
    this.kdbxCore = null;
    this.groupManager = null;
    this.entryManager = null;
    this.kdbxQuery = null;
    
    // 等待一段时间确保保存完成
    await new Promise<void>((resolve) => setTimeout(resolve, 300));
    
    // 4. 重新打开数据库
    hilog.info(0, TAG, '开始重新打开数据库，使用密码验证...');
    const reopenResult = await defaultDb.open(this.databasePassword); // 使用实际密码
    if (!reopenResult.success || !reopenResult.data) {
      // 恢复原始连接
      this.kdbxCore = originalKdbxCore;
      if (this.kdbxCore) {
        const database = this.kdbxCore.getDatabase();
        if (database) {
          this.groupManager = new KdbxGroupManager(database, this.onDatabaseEvent.bind(this));
          this.entryManager = new KdbxEntryManager(database, this.onDatabaseEvent.bind(this));
          this.kdbxQuery = new KdbxQuery(database);
        }
      }
      throw new Error(`重新打开数据库失败: ${reopenResult.error}`);
    }
    
    this.kdbxCore = reopenResult.data;
    // 更新全局KdbxCore，使UI立即使用新的数据库实例
    KdbxCoreManager.getInstance().setCurrentKdbxCore(this.kdbxCore);
    const database = this.kdbxCore.getDatabase();
    if (!database) {
      throw new Error('重新打开后无法获取数据库实例');
    }
    
    // 重新初始化管理器
    this.groupManager = new KdbxGroupManager(database, this.onDatabaseEvent.bind(this));
    this.entryManager = new KdbxEntryManager(database, this.onDatabaseEvent.bind(this));
    this.kdbxQuery = new KdbxQuery(database);
    
    hilog.info(0, TAG, '数据库重新打开成功，开始验证数据...');
    
    // 5. 详细检查重新打开后的原始数据库结构
    await this.logRawDatabaseStructure('重新打开后');
    
    // 6. 验证重新打开后的数据
    const afterGroups = this.kdbxQuery.getAllGroups();
    if (!afterGroups.success || !afterGroups.data) {
      throw new Error(`获取重新打开后分组数据失败: ${afterGroups.error}`);
    }
    
    const afterGroupsCount = afterGroups.data.length;
    let afterEntriesCount = 0;
    const afterGroupDetails: string[] = [];
    
    // 统计重新打开后的条目数 - 增加详细日志
    for (const group of afterGroups.data) {
      const entriesResult = this.entryManager.getEntriesInGroup(group.uuid.id);
      if (entriesResult.success && entriesResult.data) {
        const count = entriesResult.data.length;
        afterEntriesCount += count;
        
        const groupInfo = `${group.name || '未命名'}(${count}个条目)`;
        afterGroupDetails.push(groupInfo);
        
        // 验证每个分组的条目数是否一致
        const beforeCount = beforeEntriesMap.get(group.uuid.id) || 0;
        if (count !== beforeCount) {
          hilog.warn(0, TAG, '分组 %{public}s 条目数不一致: 保存前 %{public}d, 重新打开后 %{public}d', 
            group.name || '未命名', beforeCount, count);
        }
      }
    }
    
    hilog.info(0, TAG, '重新打开后数据统计: %{public}d 个分组, %{public}d 个条目', afterGroupsCount, afterEntriesCount);
    hilog.info(0, TAG, '分组详情: %{public}s', afterGroupDetails.join(', '));
    
    // 6. 验证数据一致性
    if (afterGroupsCount !== beforeGroupsCount) {
      hilog.error(0, TAG, '分组数量不一致: 保存前 %{public}d, 重新打开后 %{public}d', beforeGroupsCount, afterGroupsCount);
      throw new Error(`分组数量不一致: 保存前 ${beforeGroupsCount}, 重新打开后 ${afterGroupsCount}`);
    }
    
    if (afterEntriesCount !== beforeEntriesCount) {
      hilog.error(0, TAG, '条目数量不一致: 保存前 %{public}d, 重新打开后 %{public}d', beforeEntriesCount, afterEntriesCount);
      hilog.error(0, TAG, '保存前分组详情: %{public}s', beforeGroupDetails.join(', '));
      hilog.error(0, TAG, '重新打开后分组详情: %{public}s', afterGroupDetails.join(', '));
      
      // 检查是否有条目被移动到回收站
      const recycleBin = this.findRecycleBin();
      if (recycleBin) {
        const recycleBinEntries = this.entryManager.getEntriesInGroup(recycleBin.uuid.id);
        if (recycleBinEntries.success && recycleBinEntries.data) {
          hilog.error(0, TAG, '回收站中的条目数量: %{public}d', recycleBinEntries.data.length);
          if (recycleBinEntries.data.length > 0) {
            hilog.error(0, TAG, '回收站条目: %{public}s', 
              recycleBinEntries.data.map(e => e.title).join(', '));
          }
        }
      }
      
      throw new Error(`条目数量不一致: 保存前 ${beforeEntriesCount}, 重新打开后 ${afterEntriesCount}`);
    }
    
    // 7. 验证特定测试数据是否存在
    const testDataVerification = await this.verifyTestDataExists();
    if (!testDataVerification.success) {
      throw new Error(`测试数据验证失败: ${testDataVerification.error}`);
    }
    
    this.testResults.push(`✓ 数据持久化验证通过：${afterGroupsCount} 个分组，${afterEntriesCount} 个条目保持一致`);
    this.testResults.push('✓ 数据库关闭重新打开后所有测试数据完整保存');
    
    hilog.info(0, TAG, '数据持久化测试完成 - 所有数据验证通过！');
  }

  /**
   * 记录原始数据库结构 - 用于深度调试
   */
  private async logRawDatabaseStructure(stage: string): Promise<void> {
    if (!this.kdbxCore) {
      hilog.warn(0, TAG, '[%{public}s] KdbxCore未初始化', stage);
      return;
    }

    try {
      const database = this.kdbxCore.getDatabase();
      if (!database) {
        hilog.warn(0, TAG, '[%{public}s] 数据库未加载', stage);
        return;
      }

      const rootGroup = database.getDefaultGroup();
      if (!rootGroup) {
        hilog.warn(0, TAG, '[%{public}s] 根分组不存在', stage);
        return;
      }

      // 检查根分组原始属性
      hilog.info(0, TAG, '[%{public}s] 根分组原始属性:', stage);
      hilog.info(0, TAG, '  名称: "%{public}s"', rootGroup.name || 'null');
      hilog.info(0, TAG, '  UUID: %{public}s', rootGroup.uuid?.id || 'null');
      hilog.info(0, TAG, '  子分组数量: %{public}d', rootGroup.groups?.length || 0);
      hilog.info(0, TAG, '  条目数量: %{public}d', rootGroup.entries?.length || 0);

      // 递归检查所有分组的原始属性
      this.logGroupHierarchy(rootGroup, stage, 0);

    } catch (error) {
      hilog.error(0, TAG, '[%{public}s] 记录原始数据库结构失败: %{public}s', stage, (error as Error).message);
    }
  }

  /**
   * 递归记录分组层次结构
   */
  private logGroupHierarchy(group: KdbxGroup, stage: string, depth: number): void {
    const indent = '  '.repeat(depth + 1);
    
    // 记录当前分组
    hilog.info(0, TAG, '[%{public}s] %{public}s分组: "%{public}s" (UUID: %{public}s)', 
      stage, indent, group.name || 'null', group.uuid?.id || 'null');
    
    // 记录分组的条目
    if (group.entries && group.entries.length > 0) {
      for (let i = 0; i < group.entries.length; i++) {
        const entry = group.entries[i];
        const entryTitle = this.getEntryTitle(entry);
        hilog.info(0, TAG, '[%{public}s] %{public}s  条目: "%{public}s" (UUID: %{public}s)', 
          stage, indent, entryTitle || 'null', entry.uuid?.id || 'null');
      }
    }

    // 递归处理子分组
    if (group.groups && group.groups.length > 0) {
      for (let i = 0; i < group.groups.length; i++) {
        this.logGroupHierarchy(group.groups[i], stage, depth + 1);
      }
    }
  }

  /**
   * 记录数据库状态 - 用于调试
   */
  private async logDatabaseState(stage: string): Promise<void> {
    if (!this.kdbxCore || !this.kdbxQuery || !this.entryManager) {
      hilog.warn(0, TAG, '[%{public}s] 核心组件未初始化', stage);
      return;
    }

    try {
      const database = this.kdbxCore.getDatabase();
      if (!database) {
        hilog.warn(0, TAG, '[%{public}s] 数据库未加载', stage);
        return;
      }

      // 获取所有分组
      const groupsResult = this.kdbxQuery.getAllGroups();
      if (!groupsResult.success || !groupsResult.data) {
        hilog.warn(0, TAG, '[%{public}s] 无法获取分组列表: %{public}s', stage, groupsResult.error);
        return;
      }

      const groups = groupsResult.data;
      let totalEntries = 0;
      const groupDetails: string[] = [];

      // 统计每个分组的条目数
      for (const group of groups) {
        const entriesResult = this.entryManager.getEntriesInGroup(group.uuid.id);
        let entryCount = 0;
        let entryTitles: string[] = [];

        if (entriesResult.success && entriesResult.data) {
          entryCount = entriesResult.data.length;
          totalEntries += entryCount;
          entryTitles = entriesResult.data.map(e => this.getEntryTitle(e));
        }

        const groupName = group.name || '未命名';
        const groupInfo = `${groupName}(${entryCount}条目)`;
        if (entryCount > 0) {
          groupDetails.push(`${groupInfo}[${entryTitles.join(',')}]`);
        } else {
          groupDetails.push(groupInfo);
        }
      }

      // 检查回收站
      const recycleBin = this.findRecycleBin();
      let recycleBinInfo = '';
      if (recycleBin) {
        const recycleBinEntries = this.entryManager.getEntriesInGroup(recycleBin.uuid.id);
        if (recycleBinEntries.success && recycleBinEntries.data) {
          recycleBinInfo = ` 回收站: ${recycleBinEntries.data.length}条目`;
        }
      }

      hilog.info(0, TAG, '[%{public}s] 数据库状态: %{public}d个分组, %{public}d条目%{public}s', 
        stage, groups.length, totalEntries, recycleBinInfo);
      hilog.info(0, TAG, '[%{public}s] 分组详情: %{public}s', stage, groupDetails.join(' | '));

    } catch (error) {
      hilog.error(0, TAG, '[%{public}s] 记录数据库状态失败: %{public}s', stage, (error as Error).message);
    }
  }

  /**
   * 查找回收站分组
   */
  private findRecycleBin(): KdbxGroup | null {
    if (!this.kdbxCore) {
      return null;
    }
    
    const database = this.kdbxCore.getDatabase();
    if (!database) {
      return null;
    }
    
    // 尝试获取回收站分组
    const recycleBinUuid = database.meta.recycleBinUuid;
    if (recycleBinUuid) {
      const allGroups = this.kdbxQuery!.getAllGroups();
      if (allGroups.success && allGroups.data) {
        return allGroups.data.find(group => group.uuid.id === recycleBinUuid.id) || null;
      }
    }
    
    return null;
  }

  /**
   * 验证测试数据是否存在
   */
  private async verifyTestDataExists(): Promise<OperationResult<void>> {
    try {
      if (!this.kdbxQuery || !this.entryManager) {
        return {
          success: false,
          error: '查询组件未初始化',
          errorCode: 'QUERY_NOT_INITIALIZED'
        };
      }

      // 验证是否存在测试创建的分组
      const allGroups = this.kdbxQuery.getAllGroups();
      if (!allGroups.success || !allGroups.data) {
        return {
          success: false,
          error: '无法获取分组列表',
          errorCode: 'GET_GROUPS_FAILED'
        };
      }
      
      const groupNames = allGroups.data.map(g => g.name || '');
      const expectedGroups: string[] = ALL_TEMPLATES.map(t => t.name);
      const missingGroups: string[] = [];
      
      for (const expectedGroup of expectedGroups) {
        if (!groupNames.includes(expectedGroup)) {
          missingGroups.push(expectedGroup);
        }
      }
      
      if (missingGroups.length > 0) {
        return {
          success: false,
          error: `缺失预期分组: ${missingGroups.join(', ')}`,
          errorCode: 'MISSING_GROUPS'
        };
      }
      
      // 验证保留的分组是否有示例条目
      const preservedGroups: string[] = [
        '登录密码',
        '安全笔记',
        '银行账户',
        '支付账户',
        '邮箱账户',
        '会员卡',
        '会员订阅'
      ];
      
      let foundPreservedEntries = 0;
      let preservedGroupsWithEntries = 0;
      
      for (const group of allGroups.data) {
        const groupName = group.name || '';
        if (preservedGroups.includes(groupName)) {
          const entriesResult = this.entryManager.getEntriesInGroup(group.uuid.id);
          if (entriesResult.success && entriesResult.data) {
            const entryCount = entriesResult.data.length;
            if (entryCount > 0) {
              preservedGroupsWithEntries++;
              foundPreservedEntries += entryCount;
            }
          }
        }
      }
      
      if (foundPreservedEntries === 0) {
        return {
          success: false,
          error: '保留的分组中未找到任何条目',
          errorCode: 'NO_PRESERVED_ENTRIES'
        };
      }
      
      if (preservedGroupsWithEntries < 5) {
        return {
          success: false,
          error: `保留的分组中只有 ${preservedGroupsWithEntries} 个分组有条目，预期至少 5 个`,
          errorCode: 'INSUFFICIENT_PRESERVED_GROUPS'
        };
      }
      
      hilog.info(0, TAG, '数据验证通过: 找到 %{public}d 个预期分组, %{public}d 个保留分组有条目, 共 %{public}d 个条目', 
        expectedGroups.length, preservedGroupsWithEntries, foundPreservedEntries);
      
      return {
        success: true
      };
      
    } catch (error) {
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'VERIFICATION_ERROR'
      };
    }
  }

  /**
   * 保存数据库
   */
  private async saveDatabase(): Promise<void> {
    hilog.info(0, TAG, '开始保存数据库...');
    
    if (!this.kdbxCore) {
      throw new Error('数据库未初始化');
    }

    try {
      // 记录保存前的状态
      const database = this.kdbxCore.getDatabase();
      if (!database) {
        throw new Error('无法获取数据库实例');
      }

      // 使用DefaultDatabase保存数据库到文件
      const defaultDb = DefaultDatabase.getInstance();
      const saveResult = await defaultDb.saveDatabase(this.kdbxCore);
      if (!saveResult.success) {
        throw new Error(`保存数据库失败: ${saveResult.error}`);
      }
      
      // 验证保存是否成功 - 检查文件是否确实存在且有内容
      await new Promise<void>((resolve) => setTimeout(resolve, 150)); // 等待150ms确保文件写入完成
      
      const verifyResult = await defaultDb.exists();
      if (!verifyResult) {
        throw new Error('保存验证失败：数据库文件不存在');
      }
      
      hilog.info(0, TAG, '数据库保存成功，文件路径: %{public}s', saveResult.data || 'unknown');
      
      // 记录保存后的状态（用于调试）
      if (this.kdbxQuery && this.entryManager) {
        const afterSaveGroups = this.kdbxQuery.getAllGroups();
        if (afterSaveGroups.success && afterSaveGroups.data) {
          let totalEntries = 0;
          for (const group of afterSaveGroups.data) {
            const entriesResult = this.entryManager.getEntriesInGroup(group.uuid.id);
            if (entriesResult.success && entriesResult.data) {
              totalEntries += entriesResult.data.length;
            }
          }
          hilog.info(0, TAG, '保存后数据验证: %{public}d个分组, %{public}d条目', 
            afterSaveGroups.data.length, totalEntries);
        }
      }
      
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      hilog.error(0, TAG, '保存数据库时发生错误: %{public}s', errorMsg);
      throw new Error(errorMsg);
    }
  }

  /**
   * 打印测试结果
   */
  private printTestResults(): void {
    hilog.info(0, TAG, '=== 测试结果汇总 ===');
    for (const result of this.testResults) {
      hilog.info(0, TAG, result);
    }
    hilog.info(0, TAG, '=== 测试结果汇总结束 ===');
  }

  /**
   * 清理测试环境
   */
  async cleanup(): Promise<void> {
    try {
      hilog.info(0, TAG, '开始清理测试环境...');
      
      // 注意：不清理kdbxCore引用，因为主程序还需要使用它
      this.groupManager = null;
      this.entryManager = null;
      this.kdbxQuery = null;
      this.testResults = [];
      
      // 注意：不删除数据库，保留测试结果
      hilog.info(0, TAG, '测试环境清理完成，数据库已保留');
      
    } catch (error) {
      hilog.error(0, TAG, '清理测试环境失败: %{public}s', (error as Error).message);
    }
  }
}

/**
 * 执行完整的数据库CRUD测试
 */
export async function runDatabaseCRUDTest(context: Context, existingKdbxCore?: KdbxCore, password?: string): Promise<boolean> {
  const test = new DatabaseCRUDTest();
  
  try {
    // 初始化测试环境
    if (!(await test.initializeTest(context, existingKdbxCore, password))) {
      return false;
    }
    
    // 运行测试
    const result = await test.runFullCRUDTest();
    
    // 清理测试环境
    await test.cleanup();
    
    return result;
    
  } catch (error) {
    hilog.error(0, TAG, '测试执行失败: %{public}s', (error as Error).message);
    await test.cleanup();
    return false;
  }
}
