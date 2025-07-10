import { hilog } from '@kit.PerformanceAnalysisKit';
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { DefaultDatabase } from '../utils/DefaultDatabase';
import { KdbxCore, KdbxCoreManager } from '../utils/KdbxCore';
import { DatabaseFileManager } from '../utils/DatabaseFileManager';
import { runDatabaseCRUDTest } from '../test/DatabaseCRUDTest';
import { KDF_ROUNDS_PRESETS, DEFAULT_KDF_ROUNDS, getSecurityLevelName, KdfRoundsPreset } from '../utils/KdbxConstants';
import fs from '@ohos.file.fs';
import PreferencesUtil from '../utils/PreferencesUtil'

// 数据库列表项类型（与 KdbxPage 保持一致）
interface DatabaseItem {
  id: string
  name: string
  path: string
  lastModified: string
  size: number
}

const TAG = 'IndexPage';

@Entry
@Component
struct Index {
  @State isLoading: boolean = true;
  @State databaseExists: boolean = false;
  @State password: string = '';
  @State confirmPassword: string = '';
  @State errorMessage: string = '';
  @State isCreating: boolean = false;
  @State isOpening: boolean = false;
  @State testResult: string = '';
  @State creationProgress: string = '';
  @State openingProgress: string = '';
  @State selectedKdfRounds: number = DEFAULT_KDF_ROUNDS;
  @State showAdvancedOptions: boolean = false;
  @State private passwordFocused: boolean = false
  @State private openBtnError: boolean = false // 按钮错误状态
  @State private openBtnErrorText: string = '' // 错误文本
  @State private capsLockOn: boolean = false // 大写锁定状态
  @State currentDatabaseName: string = '默认密码库';
  
  private defaultDatabase: DefaultDatabase | null = null;

  aboutToAppear() {
    // 初始化首选项，后续保存数据库列表需要
    try {
      const context = getContext() as common.UIAbilityContext;
      if (!PreferencesUtil.isInitialized()) {
        PreferencesUtil.initSync(context);
      }
    } catch (e) {
      console.error('IndexPage', '初始化Preferences失败', e);
    }

    this.checkDatabaseExists();
    // 页面加载后自动获取焦点
    setTimeout(() => {
      this.passwordFocused = true;
    }, 100);
  }

  /**
   * 检查数据库是否存在 - 优先检查配置的数据库，如果不存在则fallback到默认数据库
   */
  async checkDatabaseExists() {
    try {
      // 获取应用上下文
      const context = getContext() as common.UIAbilityContext;
      
      // 获取当前选择的数据库ID
      const currId: string = PreferencesUtil.getKdbxCurrentDatabaseIdSync();
      console.log('Index', '当前配置的数据库ID:', currId);
      
      let needFallbackToDefault = false;
      
      // 如果没有配置当前数据库，直接fallback到默认数据库
      if (!currId || currId.trim() === '') {
        console.log('Index', '没有配置当前数据库，设置为默认数据库');
        needFallbackToDefault = true;
      } else {
        // 检查配置的数据库是否存在
        let currentDb: DatabaseItem | null = null;
        try {
          const listJson: string = PreferencesUtil.getKdbxDatabaseListSync();
          const list: DatabaseItem[] = JSON.parse(listJson) as DatabaseItem[];
          currentDb = list.find((it: DatabaseItem) => it.id === currId) || null;
          console.log('Index', '找到当前数据库:', currentDb?.name || '未找到');
        } catch (e) {
          console.error('Index', '解析数据库列表失败:', e);
          needFallbackToDefault = true;
        }
        
        if (!currentDb) {
          console.log('Index', '当前数据库在列表中不存在，设置为默认数据库');
          needFallbackToDefault = true;
        } else {
          // 检查配置的数据库文件是否存在
          let dbPath: string;
          if (currentDb.path.includes('/')) {
            // 绝对路径
            dbPath = currentDb.path;
          } else {
            // 相对路径（文件名）
            dbPath = `${context.filesDir}/${currentDb.path}`;
          }
          
          console.log('Index', '检查数据库文件:', dbPath);
          
          try {
            await fs.access(dbPath);
            const stat = await fs.stat(dbPath);
            
            if (stat.size > 0) {
              // 配置的数据库存在且有效
              this.databaseExists = true;
              this.currentDatabaseName = currentDb.name;
              console.log('Index', '配置的数据库文件存在且有效:', currentDb.name);
              return;
            } else {
              console.log('Index', '配置的数据库文件大小为0，设置为默认数据库');
              needFallbackToDefault = true;
            }
          } catch (accessError) {
            console.log('Index', '配置的数据库文件不存在，设置为默认数据库:', accessError);
            needFallbackToDefault = true;
          }
        }
      }
      
      // 如果需要fallback到默认数据库
      if (needFallbackToDefault) {
        console.log('Index', '设置当前数据库为默认数据库');
        PreferencesUtil.saveKdbxCurrentDatabaseIdSync('default');
        
        // 检查默认数据库是否存在
        const defaultDbPath = `${context.filesDir}/default.kdbx`;
        console.log('Index', '检查默认数据库文件:', defaultDbPath);
        
        try {
          await fs.access(defaultDbPath);
          const stat = await fs.stat(defaultDbPath);
          
          if (stat.size > 0) {
            this.databaseExists = true;
            this.currentDatabaseName = '默认密码库';
            console.log('Index', '默认数据库文件存在且有效');
            
            // 确保默认数据库在数据库列表中
            this.ensureDefaultDatabaseInList(stat.size);
          } else {
            this.databaseExists = false;
            this.currentDatabaseName = '默认密码库';
            console.log('Index', '默认数据库文件大小为0，需要创建');
          }
        } catch (accessError) {
          this.databaseExists = false;
          this.currentDatabaseName = '默认密码库';
          console.log('Index', '默认数据库文件不存在，需要创建');
        }
      }
      
    } catch (error) {
      hilog.error(0, TAG, '检查文件失败: %{public}s', (error as Error).message);
      this.databaseExists = false;
      this.currentDatabaseName = '默认密码库';
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 初始化DefaultDatabase实例 - 只在需要时调用
   */
  private initializeDefaultDatabase() {
    if (!this.defaultDatabase) {
      const context = getContext() as common.UIAbilityContext;
      this.defaultDatabase = DefaultDatabase.getInstance();
      this.defaultDatabase.setContext(context);
      hilog.info(0, TAG, 'DefaultDatabase实例已初始化');
    }
  }

  /**
   * 确保默认数据库在数据库列表中
   */
  private ensureDefaultDatabaseInList(size: number): void {
    try {
      const defaultDbItem: DatabaseItem = { 
        id: 'default', 
        name: '默认密码库', 
        path: 'default.kdbx',
        lastModified: new Date().toISOString().split('T')[0], 
        size 
      } as DatabaseItem;
      
      // 获取现有的数据库列表
      let currentList: DatabaseItem[] = [];
      try {
        const listJson = PreferencesUtil.getKdbxDatabaseListSync();
        currentList = JSON.parse(listJson) as DatabaseItem[];
      } catch (e) {
        currentList = [];
      }
      
      // 检查是否已经存在默认数据库
      const defaultIndex = currentList.findIndex(item => item.id === 'default');
      if (defaultIndex >= 0) {
        // 更新现有的默认数据库信息
        currentList[defaultIndex] = defaultDbItem;
      } else {
        // 添加默认数据库到列表开头
        currentList.unshift(defaultDbItem);
      }
      
      // 保存更新后的列表
      PreferencesUtil.saveKdbxDatabaseListSync(JSON.stringify(currentList));
      console.log('Index', '默认数据库已添加到数据库列表');
    } catch (e) {
      console.error('Index', '添加默认数据库到列表失败:', e);
    }
  }

  /**
   * 创建新的默认数据库
   */
  async createDefaultDatabase() {
    if (!this.validateCreateForm()) {
      return;
    }

    this.isCreating = true;
    this.errorMessage = '';
    this.testResult = '';
    this.creationProgress = '正在初始化...';

    try {
      hilog.info(0, TAG, '开始创建默认数据库...');
      
      // 初始化DefaultDatabase实例
      this.initializeDefaultDatabase();
      
      // 更新进度
      const securityLevelName = getSecurityLevelName(this.selectedKdfRounds);
      this.creationProgress = `正在生成密码库加密密钥（${securityLevelName}级别，${this.selectedKdfRounds}轮）...`;
      await new Promise<void>((resolve) => setTimeout(resolve, 100)); // 让UI更新
      
      // 使用DefaultDatabase创建数据库
      const result = await this.defaultDatabase!.create(this.password, this.selectedKdfRounds);
      
      if (!result.success) {
        this.errorMessage = result.error || '创建数据库失败';
        return;
      }

      const securityLevel = getSecurityLevelName(this.selectedKdfRounds);
      hilog.info(0, TAG, `默认数据库创建成功 - AES-KDF加密，${this.selectedKdfRounds}轮（${securityLevel}级别）`);
      this.creationProgress = '密码库创建完成，正在验证...';
      
      // 重新打开数据库并跳转到主界面
      const openResult = await this.defaultDatabase!.open(this.password);
      if (!openResult.success || !openResult.data) {
        this.errorMessage = openResult.error || '打开新创建的数据库失败';
        return;
      }

      // 设置全局KdbxCore实例
      if (openResult.data) {
        KdbxCoreManager.getInstance().setCurrentKdbxCore(openResult.data);
      }
      
      // 执行完整的CRUD测试
      hilog.info(0, TAG, '开始执行数据库CRUD测试...');
      this.creationProgress = '正在执行数据库功能测试...';
      this.testResult = '正在执行数据库增删改查测试...';
      
      const context = getContext() as common.UIAbilityContext;
      const testSuccess: boolean = await runDatabaseCRUDTest(context, openResult.data, this.password);
      
      if (testSuccess) {
        hilog.info(0, TAG, '数据库CRUD测试全部通过');
        this.testResult = '✓ 数据库增删改查测试全部通过！';
        this.creationProgress = '正在保存测试数据...';
        
        // 额外确保数据保存到默认数据库
        try {
          hilog.info(0, TAG, '最终保存测试数据到默认数据库...');
          const finalSaveResult = await this.defaultDatabase!.saveDatabase(openResult.data);
          if (finalSaveResult.success) {
            hilog.info(0, TAG, '测试数据最终保存成功');
            this.testResult = '✓ 数据库增删改查测试完成，数据已保存！';
            this.creationProgress = '密码库创建完成！';
          } else {
            hilog.error(0, TAG, '测试数据最终保存失败: %{public}s', finalSaveResult.error);
            this.testResult = '⚠ 测试通过但保存失败，数据可能丢失';
            this.creationProgress = '保存数据时出现问题';
          }
        } catch (saveError) {
          hilog.error(0, TAG, '最终保存时发生异常: %{public}s', (saveError as Error).message);
          this.testResult = '⚠ 测试通过但保存时出现异常';
          this.creationProgress = '保存数据时出现异常';
        }
      } else {
        hilog.error(0, TAG, '数据库CRUD测试失败');
        this.testResult = '✗ 数据库增删改查测试失败，请查看日志';
        this.creationProgress = '数据库测试失败';
      }
      
      // 等待3秒让用户看到测试结果
      // 测试完成后回到登录页，让用户自行输入密码打开数据库
      this.testResult = '✓ 密码库创建完成！请使用主密码登录';
      this.creationProgress = '';
      // 等待 2 秒以展示提示
      await new Promise<void>((resolve) => setTimeout(resolve, 2000));

      // 清理打开的实例，回到登录界面
      KdbxCoreManager.getInstance().clearCurrentKdbxCore();
      this.password = '';
      this.confirmPassword = '';
      this.capsLockOn = false; // 清除大写锁定状态
      this.databaseExists = true;
      
      // 保存数据库列表和当前ID
      try {
        const context = getContext() as common.UIAbilityContext;
        const dbPath = `${context.filesDir}/default.kdbx`;
        let size = 0;
        try { const stat = await fs.stat(dbPath); size = stat.size; } catch(e){}
        
        // 添加默认数据库到列表
        this.ensureDefaultDatabaseInList(size);
        
        // 设置当前数据库为默认数据库
        PreferencesUtil.saveKdbxCurrentDatabaseIdSync('default');
        console.log('Index', '默认数据库创建完成并添加到列表');
      } catch(e) { console.error('Index', '保存数据库列表失败', e); }
      
    } catch (error) {
      hilog.error(0, TAG, '创建数据库异常: %{public}s', (error as Error).message);
      this.errorMessage = '创建数据库时发生错误: ' + (error as Error).message;
      this.creationProgress = '创建失败';
    } finally {
      this.isCreating = false;
      this.creationProgress = '';
    }
  }

  /**
   * 打开当前选择的数据库
   */
  async openCurrentDatabase() {
    if (!this.password.trim()) {
      this.errorMessage = '请输入密码';
      return;
    }

    this.isOpening = true;
    this.errorMessage = '';
    this.openingProgress = '正在验证密码...';

    try {
      // 获取当前选择的数据库ID
      const currId: string = PreferencesUtil.getKdbxCurrentDatabaseIdSync();
      console.log('Index', '打开数据库，当前ID:', currId);
      
      if (!currId || currId.trim() === '') {
        this.errorMessage = '没有选择要打开的数据库';
        return;
      }
      
      // 从数据库列表中获取当前数据库信息
      let currentDb: DatabaseItem | null = null;
      try {
        const listJson: string = PreferencesUtil.getKdbxDatabaseListSync();
        const list: DatabaseItem[] = JSON.parse(listJson) as DatabaseItem[];
        currentDb = list.find((it: DatabaseItem) => it.id === currId) || null;
      } catch (e) {
        this.errorMessage = '获取数据库信息失败';
        return;
      }
      
      if (!currentDb) {
        this.errorMessage = '当前数据库在列表中不存在';
        return;
      }
      
      console.log('Index', '开始打开数据库:', currentDb.name);
      hilog.info(0, TAG, '开始打开数据库: %{public}s', currentDb.name);
      
      // 如果是默认数据库，使用DefaultDatabase实例
      if (currId === 'default') {
        // 初始化DefaultDatabase实例
        this.initializeDefaultDatabase();
        
        // 使用DefaultDatabase打开数据库
        this.openingProgress = '正在解密数据库...';
        const result = await this.defaultDatabase!.open(this.password);

        if (!result.success) {
          const rawErr = result.error || '';
          if (rawErr.includes('Invalid') || rawErr.toLowerCase().includes('wrong key')) {
            // 在按钮上显示 "密码错误" 2 秒
            this.openBtnError = true;
            this.openBtnErrorText = '密码错误';
            // 直接清空密码，用户可以重新输入
            this.password = '';
            this.capsLockOn = false; // 清除大写锁定状态
            setTimeout(() => {
              this.openBtnError = false;
              this.openBtnErrorText = '';
            }, 2000);
          } else {
            this.errorMessage = '打开数据库失败：' + rawErr;
          }
          return;
        }

        hilog.info(0, TAG, '数据库打开成功');
        this.openingProgress = '正在初始化界面...';
        
        // 设置全局KdbxCore实例
        if (result.data) {
          KdbxCoreManager.getInstance().setCurrentKdbxCore(result.data);
        }
        
      } else {
        // 非默认数据库，使用KdbxCore和DatabaseFileManager打开
        const context = getContext() as common.UIAbilityContext;
        
        console.log('Index', '打开数据库文件:', currentDb.path);
        this.openingProgress = '正在解密数据库...';
        
        // 使用DatabaseFileManager读取文件
        const fileManager = new DatabaseFileManager(context);
        const readResult = await fileManager.readDatabaseFromFile(currentDb.path);
        
        if (!readResult.success || !readResult.data) {
          this.errorMessage = '读取数据库文件失败：' + (readResult.error || '');
          return;
        }
        
        // 创建KdbxCore实例并加载数据库
        const kdbxCore = new KdbxCore();
        const loadResult = await kdbxCore.loadFromBuffer(readResult.data, {
          password: this.password,
          validateIntegrity: true
        });

        if (!loadResult.success) {
          const rawErr = loadResult.error || '';
          if (rawErr.includes('Invalid') || rawErr.toLowerCase().includes('wrong key')) {
            // 在按钮上显示 "密码错误" 2 秒
            this.openBtnError = true;
            this.openBtnErrorText = '密码错误';
            // 直接清空密码，用户可以重新输入
            this.password = '';
            this.capsLockOn = false; // 清除大写锁定状态
            setTimeout(() => {
              this.openBtnError = false;
              this.openBtnErrorText = '';
            }, 2000);
          } else {
            this.errorMessage = '打开数据库失败：' + rawErr;
          }
          return;
        }

        hilog.info(0, TAG, '数据库打开成功');
        this.openingProgress = '正在初始化界面...';
        
        // 设置全局KdbxCore实例
        KdbxCoreManager.getInstance().setCurrentKdbxCore(kdbxCore);
      }
      
      // 跳转到主界面
      await router.pushUrl({
        url: 'pages/MainPage'
      });

    } catch (error) {
      hilog.error(0, TAG, '打开数据库异常: %{public}s', (error as Error).message);
      this.errorMessage = '打开数据库时发生错误: ' + (error as Error).message;
      this.openingProgress = '打开失败';
    } finally {
      this.isOpening = false;
      this.openingProgress = '';
    }
  }

  /**
   * 验证创建表单
   */
  validateCreateForm(): boolean {
    if (!this.password.trim()) {
      this.errorMessage = '请输入密码';
      return false;
    }

    if (this.password.length < 8) {
      this.errorMessage = '密码长度至少需要8个字符';
      return false;
    }

    if (this.password !== this.confirmPassword) {
      this.errorMessage = '两次输入的密码不一致';
      return false;
    }

    return true;
  }

  /**
   * 清除错误信息
   */
  clearError() {
    this.errorMessage = '';
  }

  /**
   * 检测大写锁定状态（通过输入文本判断）
   */
  private checkCapsLockByText(text: string): void {
    // 简单的启发式检测：如果连续输入多个大写字母，可能是大写锁定开启
    if (text.length >= 2) {
      const lastTwoChars = text.slice(-2);
      const isAllUppercase = lastTwoChars === lastTwoChars.toUpperCase() && 
                           lastTwoChars !== lastTwoChars.toLowerCase() &&
                           /[A-Z]/.test(lastTwoChars);
      
      if (isAllUppercase) {
        this.capsLockOn = true;
      } else if (/[a-z]/.test(lastTwoChars)) {
        this.capsLockOn = false;
      }
    } else if (text.length === 0) {
      // 如果密码为空，清除大写锁定状态
      this.capsLockOn = false;
    }
  }

  build() {
    Column() {
      // 加载状态
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(60)
            .height(60)
            .margin({ bottom: 20 })
          
          Text('正在检查密码库...')
            .fontSize(16)
            .fontColor('#666666')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        // 主界面
        Column() {
          // 标题
          Text('hPassword')
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1976D2')
            .margin({ bottom: 10 })
          

          // 根据数据库是否存在显示不同界面
          if (this.databaseExists) {
            // 登录界面
            this.buildLoginForm()
          } else {
            // 创建界面
            this.buildCreateForm()
          }

          // 错误信息占位（24px 高度）
          Text(this.errorMessage)
            .fontSize(18)
            .fontColor('#F44336')
            .margin({ top: 20 })
            .textAlign(TextAlign.Center)
            .opacity(this.errorMessage ? 1 : 0)
            .height(24)
        }
        .width('100%')
        .height('100%')
        .padding(40)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
    .onClick(() => {
      // 点击空白处让密码输入框获得焦点
      this.passwordFocused = !this.passwordFocused;
    })
  }

  /**
   * 构建登录表单
   */
  @Builder
  buildLoginForm() {
    Column() {
      // 使用Row布局来突出显示密码库名称
      Row() {
        Text('输入 ')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
        
        Text(this.currentDatabaseName)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1976D2')
        
        Text(' 主密码')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
      }
      .margin({ bottom: 30 })
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      
      // 密码输入框
      TextInput({ placeholder: '请输入主密码', text: this.password })
        .defaultFocus(this.passwordFocused)
        .type(InputType.Password)
        .width('100%')
        .height(50)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .padding({ left: 16, right: 16 })
        .fontSize(16)
        .onChange((value: string) => {
          this.password = value;
          this.clearError();
          this.checkCapsLockByText(value);
        })
        .onSubmit(() => {
          this.openCurrentDatabase();
        })
        .margin({ bottom: 10 })
      
      // 大写锁定提示
      Row() {
        Text('⚠️ 大写锁定已开启')
          .fontSize(14)
          .fontColor('#FF9800')
          .opacity(this.capsLockOn ? 1 : 0)
      }
      .width('100%')
      .height(20)
      .justifyContent(FlexAlign.Start)
      .margin({ bottom: 10 })
      
      // 打开按钮
      Button(this.openBtnError ? this.openBtnErrorText : '打开密码库')
        .width('100%')
        .height(50)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.openBtnError ? '#F44336' : '#1976D2')
        .borderRadius(8)
        .enabled(!this.isOpening)
        .onClick(() => {
          this.openCurrentDatabase();
        })
      
      // 打开进度占位（总高度 60px）
      Column() {
        Row() {
          LoadingProgress()
            .width(20)
            .height(20)
            .margin({ right: 10 })
            .opacity(this.isOpening ? 1 : 0)
          
          Text('正在打开密码库...')
            .fontSize(14)
            .fontColor('#666666')
            .opacity(this.isOpening ? 1 : 0)
        }
        .margin({ top: 20 })
        .height(22)
        .alignItems(VerticalAlign.Center)
        
        // 打开进度文本
        Text(this.openingProgress)
          .fontSize(16)
          .fontColor('#999999')
          .margin({ top: 5 })
          .textAlign(TextAlign.Center)
          .opacity(this.isOpening ? 1 : 0)
          .height(18)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .height(50)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  /**
   * 构建创建表单
   */
  @Builder
  buildCreateForm() {
    Column() {
      Text('创建主密码')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 10 })
      
      Text('首次使用，请设置主密码来创建默认密码库')
        .fontSize(14)
        .fontColor('#666666')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 30 })
      
      // 密码输入框
      TextInput({ placeholder: '请输入主密码（至少8位）' })
        .type(InputType.Password)
        .width('100%')
        .height(50)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .padding({ left: 16, right: 16 })
        .fontSize(16)
        .onChange((value: string) => {
          this.password = value;
          this.clearError();
          this.checkCapsLockByText(value);
        })
        .margin({ bottom: 10 })
      
      // 确认密码输入框
      TextInput({ placeholder: '请再次输入主密码' })
        .type(InputType.Password)
        .width('100%')
        .height(50)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .padding({ left: 16, right: 16 })
        .fontSize(16)
        .onChange((value: string) => {
          this.confirmPassword = value;
          this.clearError();
          this.checkCapsLockByText(value);
        })
        .onSubmit(() => {
          this.createDefaultDatabase();
        })
        .margin({ bottom: 10 })

      // 大写锁定提示
      Row() {
        Text('⚠️ 大写锁定已开启')
          .fontSize(14)
          .fontColor('#FF9800')
          .opacity(this.capsLockOn ? 1 : 0)
      }
      .width('100%')
      .height(20)
      .justifyContent(FlexAlign.Start)
      .margin({ bottom: 10 })
      
      // 创建按钮
      Button('创建密码库')
        .width('100%')
        .height(50)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .backgroundColor('#4CAF50')
        .borderRadius(8)
        .enabled(!this.isCreating)
        .onClick(() => {
          this.createDefaultDatabase();
        })
      
      // 创建进度与测试结果占位（总高度约60px）
      Column() {
        Row() {
          LoadingProgress()
            .width(20)
            .height(20)
            .margin({ right: 10 })
            .opacity(this.isCreating ? 1 : 0)
          
          Text('正在创建密码库...')
            .fontSize(14)
            .fontColor('#666666')
            .opacity(this.isCreating ? 1 : 0)
        }
        .margin({ top: 20 })
        .height(22)
        .alignItems(VerticalAlign.Center)
        
        // 创建进度文本
        Text(this.creationProgress)
          .fontSize(14)
          .fontColor('#999999')
          .margin({ top: 5 })
          .textAlign(TextAlign.Center)
          .opacity(this.isCreating ? 1 : 0)
          .height(18)

        // 测试结果文本
        Text(this.testResult)
          .fontSize(16)
          .fontColor(this.testResult.includes('✓') ? '#4CAF50' : 
                     this.testResult.includes('✗') ? '#F44336' : '#666666')
          .margin({ top: 10 })
          .textAlign(TextAlign.Center)
          .opacity(this.isCreating ? 1 : 0)
          .height(20)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .height(60)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}