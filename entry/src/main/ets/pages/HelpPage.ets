import router from '@ohos.router'
import { LayoutPreferencesUtil } from '../utils/LayoutPreferencesUtil'
import { AutoCloseManager } from '../utils/AutoCloseManager'

import HelpItemModel from '../helps/HelpItemModel'
import { helpItems as allHelps } from '../helps/index'

@Entry
@Component
struct HelpPage {
  private helpItems: HelpItemModel[] = allHelps

  @State private selectedHelpId: string = 'intro'
  @State private firstColumnWidth: number = 250

  async aboutToAppear() {
    try {
      const layout = await LayoutPreferencesUtil.restoreLayoutStates()
      if (layout.firstWidth >= 200 && layout.firstWidth <= 300) {
        this.firstColumnWidth = layout.firstWidth
      }
      // 启动全局自动关闭计时器
      AutoCloseManager.getInstance().resume()
    } catch (error) {
      console.error('HelpPage', '读取列宽失败:', error)
    }
  }

  aboutToDisappear() {
    // 页面离开时暂停计时器
    AutoCloseManager.getInstance().pause()
  }

  build() {
    Row() {
      // 左侧导航栏
      Column() {
        // 顶部标题栏，与 MainPage 一致
        Row() {
          Text('帮助文档')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#000')
            .layoutWeight(1)

          Button() {
            Image($r('app.media.back'))
              .width(20)
              .height(20)
              .fillColor('#666')
          }
          .backgroundColor('transparent')
          .padding(4)
          .stateEffect(false)
          .onClick(() => {
            router.back()
          })
        }
        .width('100%')
        .height(50)
        .padding({ left: 16, right: 16 })
        .backgroundColor('#f8f9fa')
        .border({ width: { bottom: 1 }, color: '#e0e0e0' })

        // 帮助条目列表
        List() {
          ForEach(this.helpItems, (item: HelpItemModel) => {
            ListItem() {
              Row() {
                Image(item.icon)
                  .width(20)
                  .height(20)
                  .margin({ right: 12 })
                  .fillColor('#666666')

                Text(item.title)
                  .fontSize(17)
                  .fontWeight(FontWeight.Normal)
                  .fontColor('#000')
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
            .height(40)
            .padding({ left: 16, right: 16 })
            // 首行顶部增加 12px 间距，与 MainPage "加星" 条目一致
            .margin({ top: item.id === this.helpItems[0].id ? 12 : 0 })
            .backgroundColor(this.selectedHelpId === item.id ? '#f0f7ff' : '#fff')
            .onClick(() => {
              this.selectedHelpId = item.id
            })
          }, (item: HelpItemModel) => item.id)
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#fff')
      }
      .width(this.firstColumnWidth)
      .height('100%')
      .backgroundColor('#f8f9fa')
      .border({ width: { right: 1 }, color: '#e0e0e0' })

      // 右侧内容区
      Column() {
        Scroll() {
          Column() {
            Text(this.getSelectedHelpContent())
              .fontSize(16)
              .fontColor('#000')
              .lineHeight(24)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Start)
          .padding({ top: 16, left: 20, right: 20, bottom: 32 })
        }
        .layoutWeight(1)
        .align(Alignment.TopStart)
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor('#fff')
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 获取当前选中帮助条目的内容
   */
  private getSelectedHelpContent(): string {
    const item = this.helpItems.find(i => i.id === this.selectedHelpId)
    return item ? item.content : ''
  }
} 