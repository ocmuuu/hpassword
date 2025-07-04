import { hilog } from '@kit.PerformanceAnalysisKit';
import { router } from '@kit.ArkUI';
import { Kdbx } from '../lib';

const TAG = 'MainPage';

interface RouterParams {
  database?: Kdbx;
}

@Entry
@Component
struct MainPage {
  @State database: Kdbx | null = null;
  @State isLoading: boolean = true;

  aboutToAppear() {
    this.initializePage();
  }

  /**
   * 初始化页面
   */
  async initializePage() {
    try {
      // 获取路由参数
      const params = router.getParams() as RouterParams;
      if (params && params.database) {
        this.database = params.database;
        hilog.info(0, TAG, '数据库已加载到主页面');
      } else {
        hilog.error(0, TAG, '未获取到数据库参数，返回首页');
        await router.back();
        return;
      }
    } catch (error) {
      hilog.error(0, TAG, '初始化页面失败: %{public}s', (error as Error).message);
      await router.back();
      return;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 返回首页
   */
  async goBack() {
    await router.back();
  }

  build() {
    Column() {
      if (this.isLoading) {
        // 加载状态
        Column() {
          LoadingProgress()
            .width(60)
            .height(60)
            .margin({ bottom: 20 })
          
          Text('正在加载...')
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
          // 顶部导航栏
          Row() {
            Button('返回')
              .fontSize(16)
              .backgroundColor('#E0E0E0')
              .fontColor('#333333')
              .borderRadius(6)
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .onClick(() => {
                this.goBack();
              })
            
            Blank()
            
            Text('密码库管理')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
            
            Blank()
            
            // 占位，保持布局平衡
            Text('')
              .width(60)
          }
          .width('100%')
          .height(60)
          .padding({ left: 20, right: 20 })
          .backgroundColor('#FFFFFF')
          .border({ width: { bottom: 1 }, color: '#E0E0E0' })

          // 主内容区域
          Column() {
            if (this.database) {
              // 数据库信息
              Column() {
                Text('数据库已成功打开')
                  .fontSize(20)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#4CAF50')
                  .margin({ bottom: 20 })
                
                Text(`版本: ${this.database.versionMajor}.${this.database.versionMinor}`)
                  .fontSize(16)
                  .fontColor('#666666')
                  .margin({ bottom: 10 })
                
                Text(`名称: ${this.database.meta.name || '默认密码库'}`)
                  .fontSize(16)
                  .fontColor('#666666')
                  .margin({ bottom: 10 })
                
                Text(`生成器: ${this.database.meta.generator || '未知'}`)
                  .fontSize(16)
                  .fontColor('#666666')
                  .margin({ bottom: 30 })
                
                // 功能按钮区域
                Column() {
                  Text('功能菜单')
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .margin({ bottom: 20 })
                  
                  // 这里后续会添加各种功能按钮
                  Button('查看所有条目')
                    .width('100%')
                    .height(50)
                    .fontSize(16)
                    .backgroundColor('#2196F3')
                    .borderRadius(8)
                    .margin({ bottom: 15 })
                    .onClick(() => {
                      // TODO: 实现查看条目功能
                      hilog.info(0, TAG, '查看所有条目');
                    })
                  
                  Button('添加新条目')
                    .width('100%')
                    .height(50)
                    .fontSize(16)
                    .backgroundColor('#4CAF50')
                    .borderRadius(8)
                    .margin({ bottom: 15 })
                    .onClick(() => {
                      // TODO: 实现添加条目功能
                      hilog.info(0, TAG, '添加新条目');
                    })
                  
                  Button('管理组')
                    .width('100%')
                    .height(50)
                    .fontSize(16)
                    .backgroundColor('#FF9800')
                    .borderRadius(8)
                    .margin({ bottom: 15 })
                    .onClick(() => {
                      // TODO: 实现管理组功能
                      hilog.info(0, TAG, '管理组');
                    })
                  
                  Button('搜索')
                    .width('100%')
                    .height(50)
                    .fontSize(16)
                    .backgroundColor('#9C27B0')
                    .borderRadius(8)
                    .onClick(() => {
                      // TODO: 实现搜索功能
                      hilog.info(0, TAG, '搜索');
                    })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Center)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
            } else {
              // 错误状态
              Column() {
                Text('数据库加载失败')
                  .fontSize(18)
                  .fontColor('#F44336')
                  .margin({ bottom: 20 })
                
                Button('返回首页')
                  .fontSize(16)
                  .backgroundColor('#1976D2')
                  .borderRadius(8)
                  .onClick(() => {
                    this.goBack();
                  })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
            }
          }
          .width('100%')
          .height('100%')
          .padding(30)
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
} 