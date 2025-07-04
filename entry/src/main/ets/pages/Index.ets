import { hilog } from '@kit.PerformanceAnalysisKit';
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { DefaultDatabase } from '../utils/DefaultDatabase';
import fs from '@ohos.file.fs';

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
  
  private defaultDatabase: DefaultDatabase | null = null;

  aboutToAppear() {
    this.checkDatabaseExists();
  }

  /**
   * 检查默认数据库是否存在 - 不涉及数据库操作，只检查文件
   */
  async checkDatabaseExists() {
    try {
      // 获取应用上下文
      const context = getContext() as common.UIAbilityContext;
      
      // 构建数据库文件路径
      const dbFileName = 'default.kdbx';
      const dbPath = `${context.filesDir}/${dbFileName}`;
      
      // 使用文件系统API检查文件是否存在
      try {
        await fs.access(dbPath);
        
        // 尝试获取文件信息以确认文件有效
        try {
          const stat = await fs.stat(dbPath);
          
          // 只有文件大小大于0才认为是有效的数据库文件
          if (stat.size > 0) {
            this.databaseExists = true;
          } else {
            this.databaseExists = false;
          }
        } catch (statError) {
          // access成功但stat失败，认为文件不存在
          this.databaseExists = false;
        }
      } catch (accessError) {
        this.databaseExists = false;
      }
      
    } catch (error) {
      hilog.error(0, TAG, '检查文件失败: %{public}s', (error as Error).message);
      this.databaseExists = false;
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
   * 创建新的默认数据库
   */
  async createDefaultDatabase() {
    if (!this.validateCreateForm()) {
      return;
    }

    this.isCreating = true;
    this.errorMessage = '';

    try {
      hilog.info(0, TAG, '开始创建默认数据库...');
      
      // 初始化DefaultDatabase实例
      this.initializeDefaultDatabase();
      
      // 使用DefaultDatabase创建数据库
      const result = await this.defaultDatabase!.create(this.password);
      
      if (!result.success) {
        this.errorMessage = result.error || '创建数据库失败';
        return;
      }

      hilog.info(0, TAG, '默认数据库创建成功 - AES-KDF加密，60轮');
      
      // 重新打开数据库并跳转到主界面
      const openResult = await this.defaultDatabase!.open(this.password);
      if (!openResult.success || !openResult.data) {
        this.errorMessage = openResult.error || '打开新创建的数据库失败';
        return;
      }

      // 跳转到主界面
      await router.pushUrl({
        url: 'pages/MainPage',
        params: {
          kdbxCore: openResult.data
        }
      });

    } catch (error) {
      hilog.error(0, TAG, '创建数据库异常: %{public}s', (error as Error).message);
      this.errorMessage = '创建数据库时发生错误: ' + (error as Error).message;
    } finally {
      this.isCreating = false;
    }
  }

  /**
   * 打开现有数据库
   */
  async openDefaultDatabase() {
    if (!this.password.trim()) {
      this.errorMessage = '请输入密码';
      return;
    }

    this.isOpening = true;
    this.errorMessage = '';

    try {
      hilog.info(0, TAG, '开始打开默认数据库...');
      
      // 初始化DefaultDatabase实例
      this.initializeDefaultDatabase();
      
      // 使用DefaultDatabase打开数据库
      const result = await this.defaultDatabase!.open(this.password);

      if (!result.success) {
        this.errorMessage = result.error || '打开数据库失败';
        return;
      }

      hilog.info(0, TAG, '数据库打开成功');
      
      // 跳转到主界面
      await router.pushUrl({
        url: 'pages/MainPage',
        params: {
          kdbxCore: result.data
        }
      });

    } catch (error) {
      hilog.error(0, TAG, '打开数据库异常: %{public}s', (error as Error).message);
      this.errorMessage = '打开数据库时发生错误: ' + (error as Error).message;
    } finally {
      this.isOpening = false;
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

    if (this.password.length < 6) {
      this.errorMessage = '密码长度至少需要6个字符';
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
          
          Text('密码管理器')
            .fontSize(16)
            .fontColor('#666666')
            .margin({ bottom: 40 })

          // 根据数据库是否存在显示不同界面
          if (this.databaseExists) {
            // 登录界面
            this.buildLoginForm()
          } else {
            // 创建界面
            this.buildCreateForm()
          }

          // 错误信息
          if (this.errorMessage) {
            Text(this.errorMessage)
              .fontSize(14)
              .fontColor('#F44336')
              .margin({ top: 20 })
              .textAlign(TextAlign.Center)
          }
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
  }

  /**
   * 构建登录表单
   */
  @Builder
  buildLoginForm() {
    Column() {
      Text('输入主密码')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 30 })
      
      // 密码输入框
      TextInput({ placeholder: '请输入主密码' })
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
        })
        .margin({ bottom: 30 })
      
      // 打开按钮
      Button('打开密码库')
        .width('100%')
        .height(50)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .backgroundColor('#1976D2')
        .borderRadius(8)
        .enabled(!this.isOpening)
        .onClick(() => {
          this.openDefaultDatabase();
        })
      
      if (this.isOpening) {
        Row() {
          LoadingProgress()
            .width(20)
            .height(20)
            .margin({ right: 10 })
          
          Text('正在打开密码库...')
            .fontSize(14)
            .fontColor('#666666')
        }
        .margin({ top: 20 })
      }
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
      TextInput({ placeholder: '请输入主密码（至少6位）' })
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
        })
        .margin({ bottom: 20 })
      
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
        })
        .margin({ bottom: 30 })
      
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
      
      if (this.isCreating) {
        Row() {
          LoadingProgress()
            .width(20)
            .height(20)
            .margin({ right: 10 })
          
          Text('正在创建密码库...')
            .fontSize(14)
            .fontColor('#666666')
        }
        .margin({ top: 20 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}