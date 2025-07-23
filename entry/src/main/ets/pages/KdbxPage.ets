import router from '@ohos.router'
import { DatabaseFileManager } from '../utils/DatabaseFileManager'
import PreferencesUtil from '../utils/PreferencesUtil'
import { LayoutPreferencesUtil } from '../utils/LayoutPreferencesUtil'
import { AutoCloseManager } from '../utils/AutoCloseManager'
import fs from '@ohos.file.fs'
import DirtyFlag from '../utils/DirtyFlag'
import { KdbxCore, KdbxCoreManager } from '../utils/KdbxCore'
import { ProtectedValue, KdbxCredentials } from '../lib'
import { ClipboardUtil } from '../utils/ClipboardUtil'
import { DatabaseItem, DisplayDatabaseItem, convertToDisplayItem, isValidKdbxFileName } from '../utils/DatabaseDisplayUtil'
import picker from '@ohos.file.picker'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'

@Entry
@Component
struct KdbxPage {
  // 数据状态
  @State private databaseItems: DisplayDatabaseItem[] = []
  @State private selectedDatabaseId: string | null = null
  @State private selectedDatabase: DisplayDatabaseItem | null = null

  
  // 布局状态
  @State private isFirstColumnCollapsed: boolean = false
  @State private firstColumnWidth: number = 200
  @State private isInitialized: boolean = false
  
  // 加载状态
  @State private isLoading: boolean = false
  @State private error: string | null = null
  
  // 文件管理器
  private databaseFileManager: DatabaseFileManager | null = null

  // 查看/编辑状态
  @State private isEditing: boolean = false 
  @State private hoverFieldKey: string | null = null 
  @State private showCopySuccessToast: boolean = false 
  @State private successToastMessage: string = '复制成功'

  // 编辑状态
  @State private editingName: string = '' 
  @State private editingPassword: string = '' 
  @State private confirmEditingPassword: string = '' 

  private copySuccessTimer: number | null = null
  private formErrorTimer: number | null = null

  @State private isAddingDatabase: boolean = false 
  @State private newDbName: string = ''
  @State private newDbPath: string = ''
  @State private newPassword: string = ''
  @State private confirmPassword: string = ''
  @State private formError: string = ''
  @State private showSwitchSuccessToast: boolean = false 
  @State private switchSuccessMessage: string = '切换密码库成功'
  
  // 导入密码库相关状态
  @State private isImportingDatabase: boolean = false
  @State private importFilePath: string = ''
  @State private importFileName: string = ''
  @State private importPassword: string = ''
  @State private importConfirmPassword: string = ''
  
  // 双击检测相关
  private lastClickTime: number = 0
  private lastClickedId: string = ''
  private readonly DOUBLE_CLICK_INTERVAL: number = 300
  
  // 备份相关状态
  @State private isBackingUp: boolean = false 

  async aboutToAppear() {
    try {
      const context = getContext(this) as Context
      
      let initialized = PreferencesUtil.initSync(context)
      if (!initialized) {
        initialized = await PreferencesUtil.init(context)
      }
      
      if (initialized) {
        const layout = await LayoutPreferencesUtil.restoreLayoutStates()
        this.isFirstColumnCollapsed = layout.collapsed
        this.firstColumnWidth = layout.firstWidth
      }
      
      this.databaseFileManager = new DatabaseFileManager(context)
      
      await this.initializeData()
      
      this.isInitialized = true

      AutoCloseManager.getInstance().resume()
    } catch (error) {
      this.error = `初始化失败: ${error}`
      this.isInitialized = true
    }
  }

  aboutToDisappear() {
    AutoCloseManager.getInstance().pause()
  }

  /**
   * 初始化数据
   */
  private async initializeData() {
    try {
      this.isLoading = true
      
      await this.loadDatabaseList()
      
    } catch (error) {
      this.error = `数据初始化失败: ${error}`
    } finally {
      this.isLoading = false
    }
  }

  /**
   * 加载密码库列表
   */
  private async loadDatabaseList() {
    try {
      if (!this.databaseFileManager) {
        return
      }

      const listJson: string = PreferencesUtil.getKdbxDatabaseListSync();
      let storedList: DatabaseItem[] = [];
      try {
        storedList = JSON.parse(listJson) as DatabaseItem[];
      } catch (e) {
        console.error('KdbxPage', '解析密码库列表失败:', e);
      }

      let validOriginalList: DatabaseItem[] = [];
      if (storedList && storedList.length > 0) {
        const existenceArr: boolean[] = await Promise.all(storedList.map(async (it: DatabaseItem, index: number) => {
          try {
            let exists = false;
            
            if (!it.path || it.path.trim() === '') {
              exists = false;
            } else if (it.path.includes('/')) {
              await fs.access(it.path);
              const stat = await fs.stat(it.path);
              exists = stat.size > 0;
            } else if (this.databaseFileManager) {
              exists = await this.databaseFileManager.fileExists(it.path);
            } else {
              exists = false;
            }
            
            return exists;
          } catch(error) {
            return false;
          }
        }));
        
        validOriginalList = storedList.filter((_, idx) => existenceArr[idx]);
      }

      const context = getContext(this) as Context;
      this.databaseItems = validOriginalList.map(item => convertToDisplayItem(item, context));

      PreferencesUtil.saveKdbxDatabaseListSync(JSON.stringify(validOriginalList));

      const currentId: string = PreferencesUtil.getKdbxCurrentDatabaseIdSync();
      if (currentId) {
        const found = this.databaseItems.find(item => item.id === currentId);
        if (found) {
          this.selectedDatabaseId = found.id;
          this.selectedDatabase = {
            id: found.id,
            name: found.name,
            path: found.path,
            lastModified: found.lastModified,
            size: found.size,
            displayDir: found.displayDir,
            displayFileName: found.displayFileName,
            displaySize: found.displaySize
          };
        }
      }
       
    } catch (error) {
      console.error('KdbxPage', '加载密码库列表失败:', error)
    }
  }

  /**
   * 密码库项目点击处理 - 仅用于界面选中和查看信息，不改变当前使用的密码库
   */
  private onDatabaseItemClick(item: DisplayDatabaseItem) {
    const currentTime = Date.now()
    
    if (this.lastClickedId === item.id && 
        currentTime - this.lastClickTime < this.DOUBLE_CLICK_INTERVAL) {
      
      this.lastClickTime = 0
      this.lastClickedId = ''
      
      this.onDatabaseItemDoubleClick(item)
      return
    }
    
    this.lastClickTime = currentTime
    this.lastClickedId = item.id
    
    setTimeout(() => {
      if (this.lastClickedId === item.id) {
        this.selectedDatabaseId = item.id
        this.selectedDatabase = {
          id: item.id,
          name: item.name,
          path: item.path,
          lastModified: item.lastModified,
          size: item.size,
          displayDir: item.displayDir,
          displayFileName: item.displayFileName,
          displaySize: item.displaySize
        }
      }
    }, this.DOUBLE_CLICK_INTERVAL)
  }

  /**
   * 密码库项目双击处理 - 切换到双击的密码库
   */
  private async onDatabaseItemDoubleClick(item: DisplayDatabaseItem) {

    try {
        const currentId: string = PreferencesUtil.getKdbxCurrentDatabaseIdSync();
        
        if (item.id === currentId) {
          return;
        }
        
        const kdbxManager = KdbxCoreManager.getInstance();
        const currentCore = kdbxManager.getCurrentKdbxCore();
        if (currentCore) {
          currentCore.close(); 
        }
        kdbxManager.clearCurrentKdbxCore(); 
                
        PreferencesUtil.saveKdbxCurrentDatabaseIdSync(item.id);
        
        this.switchSuccessMessage = `已切换到: ${item.name}`;
        this.showSwitchSuccessToast = true;
      
      setTimeout(async () => {
        this.showSwitchSuccessToast = false;
        try {
          await router.replaceUrl({
            url: 'pages/Index'
          });
        } catch (routerError) {
          console.error('KdbxPage', '跳转失败:', routerError);
          await router.back();
        }
      }, 2000);
      
    } catch (error) {
      console.error('KdbxPage', '切换密码库失败:', error);
      this.showFormError('切换密码库失败');
    }
  }

  /**
   * 切换第一栏折叠状态
   */
  private onToggleFirstColumn() {
    this.isFirstColumnCollapsed = !this.isFirstColumnCollapsed
    
    LayoutPreferencesUtil.saveFirstColumnCollapseState(this.isFirstColumnCollapsed)
  }

  /**
   * 根据密码库项返回对应的图标资源
   * - 当前使用的密码库（保存在首选项中）使用 select.png
   * - 其他密码库使用 unselect.png
   */
  private getDatabaseIconRes(item: DisplayDatabaseItem): Resource {
    const currentId: string = PreferencesUtil.getKdbxCurrentDatabaseIdSync();
    return item.id === currentId ? $r('app.media.select') : $r('app.media.unselect');
  }

  /** 复制文本到剪贴板并显示提示 */
  private async copyToClipboard(text: string): Promise<void> {
    try {
      await ClipboardUtil.copy(text)

      if (this.copySuccessTimer !== null) {
        clearTimeout(this.copySuccessTimer)
        this.copySuccessTimer = null
      }

      this.successToastMessage = '复制成功'
      this.showCopySuccessToast = true

      this.copySuccessTimer = setTimeout(() => {
        this.showCopySuccessToast = false
        this.copySuccessTimer = null
      }, 2500)
    } catch (e) {
      console.error('KdbxPage', '复制失败', e)
    }
  }

  /** 显示错误提示并自动隐藏 */
  private showFormError(message: string): void {
    if (this.formErrorTimer !== null) {
      clearTimeout(this.formErrorTimer)
      this.formErrorTimer = null
    }

    this.formError = message

    this.formErrorTimer = setTimeout(() => {
      this.formError = ''
      this.formErrorTimer = null
    }, 3000)
  }

  /** 字段项视图，与 MainPage.DetailFieldView 一致 */
  @Builder
  private DetailFieldView(label: string, value: string) {
    Column() {
      Row() {
        Text(label)
          .fontSize(16)
          .fontColor('#666')
          .fontWeight(FontWeight.Medium)
          .width(120)

        Text(value)
          .fontSize(16)
          .fontColor('#000')
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
          .margin({ left: 8 })

        Button('复制')
          .fontSize(12)
          .backgroundColor('#f0f0f0')
          .fontColor('#000')
          .borderRadius(3)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .opacity(this.hoverFieldKey === label ? 1 : 0)
          .onClick(() => {
            this.copyToClipboard(value)
          })
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      .backgroundColor(this.hoverFieldKey === label ? '#f5f5f5' : '#fff')
      .alignItems(VerticalAlign.Center)
      .onHover((isHover: boolean) => {
        this.hoverFieldKey = isHover ? label : (this.hoverFieldKey === label ? null : this.hoverFieldKey)
      })

      Divider()
        .strokeWidth(1)
        .color('#f0f0f0')
        .margin({ top: 4, bottom: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.copyToClipboard(value)
    })
  }



  /**
   * 密码库信息查看面板
   */
  @Builder
  private InfoPanelView() {
    if (this.selectedDatabase) {
      Column() {
        Column() {
          Column() {
            Row() {
              Text('密码库名称')
                .fontSize(16)
                .fontColor('#666')
                .fontWeight(FontWeight.Medium)
                .width(120)

              Text(this.selectedDatabase.name)
                .fontSize(16)
                .fontColor('#000')
                .layoutWeight(1)
                .textAlign(TextAlign.Start)
                .margin({ left: 8 })

              Button('复制')
                .fontSize(12)
                .backgroundColor('#f0f0f0')
                .fontColor('#000')
                .borderRadius(3)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .opacity(this.hoverFieldKey === '密码库名称' ? 1 : 0)
                .onClick(() => {
                  if (this.selectedDatabase) {
                    this.copyToClipboard(this.selectedDatabase.name)
                  }
                })
            }
            .width('100%')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor(this.hoverFieldKey === '密码库名称' ? '#f5f5f5' : '#fff')
            .alignItems(VerticalAlign.Center)
            .onHover((isHover: boolean) => {
              this.hoverFieldKey = isHover ? '密码库名称' : (this.hoverFieldKey === '密码库名称' ? null : this.hoverFieldKey)
            })

            Divider()
              .strokeWidth(1)
              .color('#f0f0f0')
              .margin({ top: 4, bottom: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .onClick(() => {
            if (this.selectedDatabase) {
              this.copyToClipboard(this.selectedDatabase.name)
            }
          })

          Column() {
            Row() {
              Text('密码库路径')
                .fontSize(16)
                .fontColor('#666')
                .fontWeight(FontWeight.Medium)
                .width(120)

              Text(this.selectedDatabase.displayDir)
                .fontSize(16)
                .fontColor('#000')
                .layoutWeight(1)
                .textAlign(TextAlign.Start)
                .margin({ left: 8 })

              Button('复制')
                .fontSize(12)
                .backgroundColor('#f0f0f0')
                .fontColor('#000')
                .borderRadius(3)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .opacity(this.hoverFieldKey === '密码库路径' ? 1 : 0)
                .onClick(() => {
                  if (this.selectedDatabase) {
                    this.copyToClipboard(this.selectedDatabase.displayDir)
                  }
                })
            }
            .width('100%')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor(this.hoverFieldKey === '密码库路径' ? '#f5f5f5' : '#fff')
            .alignItems(VerticalAlign.Center)
            .onHover((isHover: boolean) => {
              this.hoverFieldKey = isHover ? '密码库路径' : (this.hoverFieldKey === '密码库路径' ? null : this.hoverFieldKey)
            })

            Divider()
              .strokeWidth(1)
              .color('#f0f0f0')
              .margin({ top: 4, bottom: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .onClick(() => {
            if (this.selectedDatabase) {
              this.copyToClipboard(this.selectedDatabase.displayDir)
            }
          })

          Column() {
            Row() {
              Text('密码库文件名')
                .fontSize(16)
                .fontColor('#666')
                .fontWeight(FontWeight.Medium)
                .width(120)

              Text(this.selectedDatabase.displayFileName)
                .fontSize(16)
                .fontColor('#000')
                .layoutWeight(1)
                .textAlign(TextAlign.Start)
                .margin({ left: 8 })

              Button('复制')
                .fontSize(12)
                .backgroundColor('#f0f0f0')
                .fontColor('#000')
                .borderRadius(3)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .opacity(this.hoverFieldKey === '密码库文件名' ? 1 : 0)
                .onClick(() => {
                  if (this.selectedDatabase) {
                    this.copyToClipboard(this.selectedDatabase.displayFileName)
                  }
                })
            }
            .width('100%')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor(this.hoverFieldKey === '密码库文件名' ? '#f5f5f5' : '#fff')
            .alignItems(VerticalAlign.Center)
            .onHover((isHover: boolean) => {
              this.hoverFieldKey = isHover ? '密码库文件名' : (this.hoverFieldKey === '密码库文件名' ? null : this.hoverFieldKey)
            })

            Divider()
              .strokeWidth(1)
              .color('#f0f0f0')
              .margin({ top: 4, bottom: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .onClick(() => {
            if (this.selectedDatabase) {
              this.copyToClipboard(this.selectedDatabase.displayFileName)
            }
          })

          Column() {
            Row() {
              Text('最后修改')
                .fontSize(16)
                .fontColor('#666')
                .fontWeight(FontWeight.Medium)
                .width(120)

              Text(this.selectedDatabase.lastModified)
                .fontSize(16)
                .fontColor('#000')
                .layoutWeight(1)
                .textAlign(TextAlign.Start)
                .margin({ left: 8 })

              Button('复制')
                .fontSize(12)
                .backgroundColor('#f0f0f0')
                .fontColor('#000')
                .borderRadius(3)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .opacity(this.hoverFieldKey === '最后修改' ? 1 : 0)
                .onClick(() => {
                  if (this.selectedDatabase) {
                    this.copyToClipboard(this.selectedDatabase.lastModified)
                  }
                })
            }
            .width('100%')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor(this.hoverFieldKey === '最后修改' ? '#f5f5f5' : '#fff')
            .alignItems(VerticalAlign.Center)
            .onHover((isHover: boolean) => {
              this.hoverFieldKey = isHover ? '最后修改' : (this.hoverFieldKey === '最后修改' ? null : this.hoverFieldKey)
            })

            Divider()
              .strokeWidth(1)
              .color('#f0f0f0')
              .margin({ top: 4, bottom: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .onClick(() => {
            if (this.selectedDatabase) {
              this.copyToClipboard(this.selectedDatabase.lastModified)
            }
          })

          Column() {
            Row() {
              Text('大小')
                .fontSize(16)
                .fontColor('#666')
                .fontWeight(FontWeight.Medium)
                .width(120)

              Text(this.selectedDatabase.displaySize)
                .fontSize(16)
                .fontColor('#000')
                .layoutWeight(1)
                .textAlign(TextAlign.Start)
                .margin({ left: 8 })

              Button('复制')
                .fontSize(12)
                .backgroundColor('#f0f0f0')
                .fontColor('#000')
                .borderRadius(3)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .opacity(this.hoverFieldKey === '大小' ? 1 : 0)
                .onClick(() => {
                  if (this.selectedDatabase) {
                    this.copyToClipboard(this.selectedDatabase.displaySize)
                  }
                })
            }
            .width('100%')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor(this.hoverFieldKey === '大小' ? '#f5f5f5' : '#fff')
            .alignItems(VerticalAlign.Center)
            .onHover((isHover: boolean) => {
              this.hoverFieldKey = isHover ? '大小' : (this.hoverFieldKey === '大小' ? null : this.hoverFieldKey)
            })

            Divider()
              .strokeWidth(1)
              .color('#f0f0f0')
              .margin({ top: 4, bottom: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .onClick(() => {
            if (this.selectedDatabase) {
              this.copyToClipboard(this.selectedDatabase.displaySize)
            }
          })

          // 备份密码库按钮
          Button() {
            Row() {
              Image($r('app.media.icon'))
                .width(16)
                .height(16)
                .fillColor('#fff')
                .margin({ right: 8 })

              Text('备份密码库')
                .fontSize(14)
                .fontColor('#fff')
                .fontWeight(FontWeight.Medium)
            }
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
          }
          .width('30%')
          .height(40)
          .backgroundColor('#52c41a')
          .borderRadius(8)
          .margin({ left: 16, right: 16, top: 20, bottom: 10 })
          .opacity(this.isBackingUp ? 0.6 : 1)
          .enabled(!this.isBackingUp)
          .onClick(() => {
            this.backupDatabase();
          })

          Blank()
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 16 })
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
    } else {
      Column() {
        Column() {
          Image($r('app.media.startIcon'))
            .width(80)
            .height(80)
            .opacity(0.3)
            .margin({ bottom: 16 })

          Text('选择一个密码库查看信息')
            .fontSize(16)
            .fontColor('#999')

          Text('从左侧列表中选择要查看的密码库')
            .fontSize(14)
            .fontColor('#ccc')
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#fff')
    }
  }

  /**
   * 返回主页
   */
  private async onBackToMain() {
    router.back()
  }

  /**
   * 创建密码库项目视图
   */
  @Builder
  private DatabaseItemView(item: DisplayDatabaseItem) {
    Row() {
      Image(this.getDatabaseIconRes(item))
        .width(20)
        .height(20)
        .margin({ right: 12 })

      Column() {
        Text(item.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#000')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)

        Text(`${item.lastModified} · ${(item.size / 1024).toFixed(1)}KB`)
          .fontSize(14)
          .fontColor('#666')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(60)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.selectedDatabaseId === item.id ? '#f0f7ff' : '#fff')
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onDatabaseItemClick(item)
    })
  }

  /**
   * 创建编辑面板视图
   */
  @Builder
  private EditPanelView() {
    if (this.selectedDatabase) {
      Column() {
        Scroll() {
          Column() {
            Column() {
              Text('编辑密码库')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#000')
                .margin({ bottom: 16 })

              Column() {
                Text('密码库名称')
                  .fontSize(16)
                  .fontColor('#333')
                  .fontWeight(FontWeight.Medium)
                  .margin({ bottom: 8 })

                TextInput({ 
                  placeholder: '请输入密码库名称',
                  text: this.editingName
                })
                  .fontSize(16)
                  .border({ width: 1, color: '#ddd' })
                  .borderRadius(4)
                  .padding(12)
                  .maxLength(50)
                  .onChange((value: string) => {
                    this.editingName = value;
                  })
              }
              .width('100%')
              .margin({ bottom: 16 })
              .alignItems(HorizontalAlign.Start)

              Column() {
                Text('新主密码（可选）')
                  .fontSize(16)
                  .fontColor('#333')
                  .fontWeight(FontWeight.Medium)
                  .margin({ bottom: 8 })

                TextInput({ 
                  placeholder: '如需修改主密码，请输入新密码（至少8位）',
                  text: this.editingPassword
                })
                  .type(InputType.Password)
                  .fontSize(16)
                  .border({ width: 1, color: '#ddd' })
                  .borderRadius(4)
                  .padding(12)
                  .onChange((value: string) => {
                    this.editingPassword = value;
                  })
              }
              .width('100%')
              .margin({ bottom: 16 })
              .alignItems(HorizontalAlign.Start)

              Column() {
                Text('确认主密码')
                  .fontSize(16)
                  .fontColor('#333')
                  .fontWeight(FontWeight.Medium)
                  .margin({ bottom: 8 })

                TextInput({ 
                  placeholder: '再次输入新主密码',
                  text: this.confirmEditingPassword
                })
                  .type(InputType.Password)
                  .fontSize(16)
                  .border({ width: 1, color: '#ddd' })
                  .borderRadius(4)
                  .padding(12)
                  .enabled(this.editingPassword.trim() !== '')
                  .opacity(this.editingPassword.trim() !== '' ? 1 : 0.5)
                  .onChange((value: string) => {
                    this.confirmEditingPassword = value;
                  })
              }
              .width('100%')
              .margin({ bottom: 16 })
              .alignItems(HorizontalAlign.Start)

              Column() {
                Text('说明')
                  .fontSize(16)
                  .fontColor('#333')
                  .fontWeight(FontWeight.Medium)
                  .margin({ bottom: 8 })

                Text('• 只有当前打开的密码库可以编辑\n• 如果不需要修改主密码，请保持密码字段为空\n• 修改主密码后需要重新打开密码库')
                  .fontSize(14)
                  .fontColor('#666')
                  .lineHeight(20)
                  .padding(12)
                  .backgroundColor('#f9f9f9')
                  .borderRadius(4)
              }
              .width('100%')
              .margin({ bottom: 16 })
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 16 })
            .alignItems(HorizontalAlign.Start)

            Row() {
              Button('保存')
                .fontSize(14)
                .backgroundColor('#4CAF50')
                .fontColor('#fff')
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .borderRadius(4)
                .margin({ right: 8 })
                .onClick(() => {
                  this.saveEditChanges();
                })

              Button('取消')
                .fontSize(14)
                .backgroundColor('#f0f0f0')
                .fontColor('#666')
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .borderRadius(4)
                .onClick(() => {
                  this.cancelEditMode();
                })
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 16, bottom: 16 })
            .justifyContent(FlexAlign.Start)

            Blank()
              .layoutWeight(1)
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
        }
        .layoutWeight(1)
        .backgroundColor('#fff')
      }
      .width('100%')
      .height('100%')
    } else {
      Column() {
        Column() {
          Image($r('app.media.startIcon'))
            .width(80)
            .height(80)
            .opacity(0.3)
            .margin({ bottom: 16 })

          Text('选择一个密码库进行编辑')
            .fontSize(16)
            .fontColor('#999')

          Text('从左侧列表中选择要编辑的密码库')
            .fontSize(14)
            .fontColor('#ccc')
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#fff')
    }
  }

  private async createNewDatabase() {
    const defaultName: string = `我的密码库${this.databaseItems.length + 1}`;
    this.newDbName = defaultName;
    const defaultPath: string = `personal${this.databaseItems.length + 1}`;
    this.newDbPath = `${defaultPath}.kdbx`;
    this.isAddingDatabase = true;
  }

  /** 保存新密码库条目 */
  private async saveNewDatabase() {
    if (!this.newDbName.trim()) {
      this.showFormError('名称不能为空');
      return;
    }
    if (!this.newPassword.trim() || this.newPassword.length < 8) {
      this.showFormError('密码至少8位');
      return;
    }
    if (this.newPassword !== this.confirmPassword) {
      this.showFormError('两次密码不一致');
      return;
    }

    if (this.newDbPath.includes('/')) {
      this.showFormError('仅输入文件名，不含路径');
      return;
    }
    if (!isValidKdbxFileName(this.newDbPath.trim())) {
      this.showFormError('文件名仅允许英文、数字、下划线，且以 .kdbx 结尾');
      return;
    }

    try {
      const context = getContext(this) as Context;
      const fileNameOnly: string = this.newDbPath.trim();
      const finalPath: string = `${context.filesDir}/${fileNameOnly}`;

      let fileExists = false;
      try {
        if (fileNameOnly.includes('/')) {
          await fs.access(fileNameOnly);
          fileExists = true;
        } else {
          if (this.databaseFileManager) {
            fileExists = await this.databaseFileManager.fileExists(fileNameOnly);
          }
        }
        
        if (fileExists) {
          this.showFormError(`文件 ${fileNameOnly} 已存在，请使用其他文件名`);
          return;
        }
        
      } catch (error) {
        console.error('KdbxPage', '文件检测失败:', error);
      }

      const core = new KdbxCore();
      const createResult = await core.createNew(this.newPassword, this.newDbName.trim());
      if (!createResult.success || !createResult.data) {
        this.showFormError(createResult.error || '创建密码库失败');
        return;
      }

      const db = createResult.data;
      const root = db.getDefaultGroup();
      if (root) {
        const entry1 = db.createEntry(root);
        entry1.fields.set('Title', '示例1');
        entry1.fields.set('UserName', 'user1');
        entry1.fields.set('Password', ProtectedValue.fromString('pass1'));

        const entry2 = db.createEntry(root);
        entry2.fields.set('Title', '示例2');
        entry2.fields.set('UserName', 'user2');
        entry2.fields.set('Password', ProtectedValue.fromString('pass2'));
      }

      const fileManager = new DatabaseFileManager(getContext(this) as Context);
      const saveRes = await fileManager.saveDatabaseToFile(db, fileNameOnly, true);
      if (!saveRes.success) {
        this.showFormError(saveRes.error || '保存密码库失败');
        return;
      }

      const actualPath: string = saveRes.data ?? fileManager.getFilePath(fileNameOnly);

      let size = 0;
      try { const stat = await fs.stat(actualPath); size = stat.size; } catch(_) {}

      const newId: string = Date.now().toString();
      const newOriginalItem: DatabaseItem = {
        id: newId,
        name: this.newDbName.trim(),
        path: fileNameOnly,  
        lastModified: new Date().toISOString().split('T')[0],
        size: size
      };

      let currentOriginalList: DatabaseItem[] = [];
      try {
        const listJson = PreferencesUtil.getKdbxDatabaseListSync();
        currentOriginalList = JSON.parse(listJson) as DatabaseItem[];
      } catch (e) {
        currentOriginalList = [];
      }
      
      currentOriginalList.push(newOriginalItem);
      PreferencesUtil.saveKdbxDatabaseListSync(JSON.stringify(currentOriginalList));

      const ctxNew = getContext(this) as Context;
      const newDisplayItem = convertToDisplayItem(newOriginalItem, ctxNew);
      this.databaseItems.push(newDisplayItem);

      this.isAddingDatabase = false;
      this.selectedDatabaseId = newId;
      this.selectedDatabase = {
        id: newDisplayItem.id,
        name: newDisplayItem.name,
        path: newDisplayItem.path,
        lastModified: newDisplayItem.lastModified,
        size: newDisplayItem.size,
        displayDir: newDisplayItem.displayDir,
        displayFileName: newDisplayItem.displayFileName,
        displaySize: newDisplayItem.displaySize
      };

    } catch (e) {
      console.error('KdbxPage', '保存新密码库失败', e);
      this.showFormError('创建密码库时发生异常');
    }
  }

  private cancelNewDatabase() {
    this.isAddingDatabase = false;
    this.newPassword = '';
    this.confirmPassword = '';
    
    if (this.formErrorTimer !== null) {
      clearTimeout(this.formErrorTimer);
      this.formErrorTimer = null;
    }
    this.formError = '';
  }

  /** 选择并导入外部密码库文件 */
  private async selectDatabaseFile() {
    this.isImportingDatabase = true;
    this.importFilePath = '';
    this.importFileName = '';
    this.importPassword = '';
    this.importConfirmPassword = '';
  }

  /** 从文件系统选择密码库文件 */
  private async pickDatabaseFile() {
    try {
      const context = getContext(this) as common.Context;
      const documentPicker = new picker.DocumentViewPicker(context);
      const documentSelectOptions = new picker.DocumentSelectOptions();
      
      // 设置选择选项
      documentSelectOptions.maxSelectNumber = 1;
      documentSelectOptions.fileSuffixFilters = ['密码库文件|.kdbx'];
      
      const result = await documentPicker.select(documentSelectOptions);
      
      if (result && result.length > 0) {
        const fileUri = result[0];
        this.importFilePath = fileUri;
        
        // 解码URL编码的文件名，去除%编码
        let fileName = fileUri.split('/').pop() || '未知文件';
        try {
          fileName = decodeURIComponent(fileName);
        } catch (error) {
          // 如果解码失败，使用原始文件名
          console.warn('KdbxPage', '导入文件名解码失败:', error);
        }
        this.importFileName = fileName;
        
        // 验证文件是否存在且可读
        try {
          const file = fs.openSync(fileUri, fs.OpenMode.READ_ONLY);
          const stat = await fs.stat(file.fd);
          fs.closeSync(file);
          
          if (stat.size === 0) {
            this.showFormError('选择的文件为空');
            this.importFilePath = '';
            this.importFileName = '';
            return;
          }
        } catch (error) {
          this.showFormError('无法读取选择的文件');
          this.importFilePath = '';
          this.importFileName = '';
          return;
        }
      }
    } catch (error) {
      console.error('KdbxPage', '选择文件失败:', error);
      this.showFormError('文件选择失败');
    }
  }

  /** 取消导入密码库 */
  private cancelImportDatabase() {
    this.isImportingDatabase = false;
    this.importFilePath = '';
    this.importFileName = '';
    this.importPassword = '';
    this.importConfirmPassword = '';
    
    if (this.formErrorTimer !== null) {
      clearTimeout(this.formErrorTimer);
      this.formErrorTimer = null;
    }
    this.formError = '';
  }

  /** 确认导入选择的密码库文件 */
  private async confirmImportDatabase() {
    if (!this.importFilePath) {
      this.showFormError('请先选择密码库文件');
      return;
    }
    
    if (!this.importPassword.trim()) {
      this.showFormError('请输入密码');
      return;
    }

    try {
      // 读取文件内容
      const file = fs.openSync(this.importFilePath, fs.OpenMode.READ_ONLY);
      const stat = await fs.stat(file.fd);
      const arrayBuffer = new ArrayBuffer(stat.size);
      await fs.read(file.fd, arrayBuffer);
      fs.closeSync(file);

      // 尝试使用KdbxCore加载数据库
      const kdbxCore = new KdbxCore();
      const loadResult = await kdbxCore.loadFromBuffer(arrayBuffer, {
        password: this.importPassword,
        validateIntegrity: true
      });

      if (!loadResult.success) {
        const errorMsg: string = loadResult.error || '';
        
        if (errorMsg.includes('Invalid') || errorMsg.toLowerCase().includes('wrong key')) {
          this.showFormError('密码错误，请重试');
        } else if (errorMsg.includes('argon2 not implemented') || errorMsg.includes('bad kdf')) {
          this.showFormError('此密码库使用 Argon2 密钥派生函数，当前版本暂不支持。请使用 AES-KDF 类型的密码库。');
        } else {
          this.showFormError('无法打开密码库: ' + errorMsg);
        }
        return;
      }

      // 获取数据库名称
      const database = kdbxCore.getDatabase();
      const dbName: string = database?.meta?.name || this.importFileName.replace('.kdbx', '');
      
      // 复制文件到应用私有目录
      const context = getContext(this) as Context;
      const timestamp = Date.now().toString();
      const internalFileName = `imported_${timestamp}.kdbx`;
      const internalPath = `${context.filesDir}/${internalFileName}`;
      
      // 将文件复制到内部存储
      const sourceFile = fs.openSync(this.importFilePath, fs.OpenMode.READ_ONLY);
      const targetFile = fs.openSync(internalPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      
      const sourceBuffer = new ArrayBuffer(stat.size);
      await fs.read(sourceFile.fd, sourceBuffer);
      await fs.write(targetFile.fd, sourceBuffer);
      
      fs.closeSync(sourceFile);
      fs.closeSync(targetFile);

      // 添加到密码库列表
      const newId = Date.now().toString();
      const newOriginalItem: DatabaseItem = {
        id: newId,
        name: dbName,
        path: internalFileName,  // 使用内部文件名
        lastModified: new Date().toISOString().split('T')[0],
        size: stat.size
      };

      let currentOriginalList: DatabaseItem[] = [];
      try {
        const listJson = PreferencesUtil.getKdbxDatabaseListSync();
        currentOriginalList = JSON.parse(listJson) as DatabaseItem[];
      } catch (e) {
        currentOriginalList = [];
      }
      
      currentOriginalList.push(newOriginalItem);
      PreferencesUtil.saveKdbxDatabaseListSync(JSON.stringify(currentOriginalList));

      const ctxNew = getContext(this) as Context;
      const newDisplayItem = convertToDisplayItem(newOriginalItem, ctxNew);
      this.databaseItems.push(newDisplayItem);

      // 设置为当前选中的密码库
      this.selectedDatabaseId = newId;
      this.selectedDatabase = {
        id: newDisplayItem.id,
        name: newDisplayItem.name,
        path: newDisplayItem.path,
        lastModified: newDisplayItem.lastModified,
        size: newDisplayItem.size,
        displayDir: newDisplayItem.displayDir,
        displayFileName: newDisplayItem.displayFileName,
        displaySize: newDisplayItem.displaySize
      };

      this.cancelImportDatabase();
      
      this.successToastMessage = `密码库 "${dbName}" 已成功导入`;
      this.showCopySuccessToast = true;
      
      if (this.copySuccessTimer !== null) {
        clearTimeout(this.copySuccessTimer);
      }
      this.copySuccessTimer = setTimeout(() => {
        this.showCopySuccessToast = false;
        this.copySuccessTimer = null;
      }, 3000);

    } catch (error) {
      console.error('KdbxPage', '导入密码库失败:', error);
      this.showFormError('导入密码库时发生异常');
    }
  }

  /** 备份密码库到用户选择的位置 */
  private async backupDatabase() {
    if (!this.selectedDatabase || this.isBackingUp) {
      return;
    }

    this.isBackingUp = true;

    try {
      const context = getContext(this) as common.Context;
      
      // 获取密码库文件路径
      let sourceFilePath: string;
      if (this.selectedDatabase.path.includes('/')) {
        // 绝对路径
        sourceFilePath = this.selectedDatabase.path;
      } else {
        // 相对路径（应用内部文件）
        sourceFilePath = `${context.filesDir}/${this.selectedDatabase.path}`;
      }

      // 检查源文件是否存在
      try {
        await fs.access(sourceFilePath);
      } catch (error) {
        this.showFormError('密码库文件不存在或无法访问');
        return;
      }

      // 读取源文件内容
      const sourceFile = fs.openSync(sourceFilePath, fs.OpenMode.READ_ONLY);
      const stat = await fs.stat(sourceFile.fd);
      const fileContent = new ArrayBuffer(stat.size);
      await fs.read(sourceFile.fd, fileContent);
      fs.closeSync(sourceFile);

      // 生成默认备份文件名
      const timestamp = new Date().toISOString().split('T')[0].replace(/-/g, '');
      const timeStr = new Date().toTimeString().split(' ')[0].replace(/:/g, '');
      const defaultBackupFileName = `${this.selectedDatabase.name}_备份_${timestamp}_${timeStr}.kdbx`;

      // 使用DocumentViewPicker让用户选择保存位置
      const documentPicker = new picker.DocumentViewPicker(context);
      const documentSaveOptions = new picker.DocumentSaveOptions();
      
      // 设置默认文件名
      documentSaveOptions.newFileNames = [defaultBackupFileName];
      
      const saveResult = await documentPicker.save(documentSaveOptions);
      
      if (saveResult && saveResult.length > 0) {
        const targetPath = saveResult[0];
        
        // 写入到用户选择的位置
        const targetFile = fs.openSync(targetPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        await fs.write(targetFile.fd, fileContent);
        fs.closeSync(targetFile);

        // 显示成功提示
        let displayPath = targetPath;
        // 解码URL编码的路径，去除%编码
        try {
          displayPath = decodeURIComponent(targetPath);
        } catch (error) {
          // 如果解码失败，使用原始路径
          console.warn('KdbxPage', '路径解码失败:', error);
        }
        
        const fileName = displayPath.split('/').pop() || defaultBackupFileName;
        this.successToastMessage = `备份成功！已保存: ${fileName}`;
        this.showCopySuccessToast = true;
        
        if (this.copySuccessTimer !== null) {
          clearTimeout(this.copySuccessTimer);
        }
        this.copySuccessTimer = setTimeout(() => {
          this.showCopySuccessToast = false;
          this.copySuccessTimer = null;
        }, 4000);

        console.info('KdbxPage', '密码库备份成功:', targetPath);
      } else {
        // 用户取消了保存操作
        console.info('KdbxPage', '用户取消了备份操作');
      }
      
    } catch (error) {
      console.error('KdbxPage', '备份密码库失败:', error);
      this.showFormError('备份密码库失败，请重试');
    } finally {
      this.isBackingUp = false;
    }
  }

  /** 新增密码库表单视图 */
  @Builder
  private CreateDatabaseFormView() {
    Column() {
      Column() {
        Column() {
          Text('密码库名称')
            .fontSize(16)
            .fontColor('#333')
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 8 })

          TextInput({ text: this.newDbName, placeholder: '请输入密码库名称' })
            .onChange((val: string) => {
              this.newDbName = val;
            })
            .fontSize(16)
            .border({ width: 1, color: '#ddd' })
            .borderRadius(4)
            .padding(12)
        }
        .width('100%')
        .margin({ bottom: 16 })
        .alignItems(HorizontalAlign.Start)

        Column() {
          Text('文件名或完整路径')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333')
            .margin({ bottom: 6 })

          TextInput({ text: this.newDbPath, placeholder: '如 mydb.kdbx 或 /storage/XXX/mydb.kdbx' })
            .onChange((val: string) => {
              this.newDbPath = val;
            })
            .fontSize(16)
            .border({ width: 1, color: '#ddd' })
            .borderRadius(4)
            .padding(12)
        }
        .width('100%')
        .margin({ bottom: 16 })
        .alignItems(HorizontalAlign.Start)

        Column() {
          Text('主密码')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333')
            .margin({ bottom: 6 })

          TextInput({ text: this.newPassword, placeholder: '请输入主密码' })
            .type(InputType.Password)
            .onChange((val: string) => {
              this.newPassword = val;
            })
            .fontSize(16)
            .border({ width: 1, color: '#ddd' })
            .borderRadius(4)
            .padding(12)
        }
        .width('100%')
        .margin({ bottom: 16 })
        .alignItems(HorizontalAlign.Start)

        Column() {
          Text('确认密码')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333')
            .margin({ bottom: 6 })

          TextInput({ text: this.confirmPassword, placeholder: '再次输入主密码' })
            .type(InputType.Password)
            .onChange((val: string) => {
              this.confirmPassword = val;
            })
            .fontSize(16)
            .border({ width: 1, color: '#ddd' })
            .borderRadius(4)
            .padding(12)
        }
        .width('100%')
        .margin({ bottom: 16 })
        .alignItems(HorizontalAlign.Start)

        Row() {
          Button('创建新的密码库')
            .width('30%')
            .height(40)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#1976D2')
            .borderRadius(8)
            .margin({ right: 5 })
            .onClick(() => {
              this.saveNewDatabase();
            })

          Button('取消')
            .height(40)
            .fontSize(14)
            .backgroundColor('#f0f0f0')
            .fontColor('#000')
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .borderRadius(6)
            .onClick(() => {
              this.cancelNewDatabase();
            })
        }
        .width('100%')
        .margin({ top: 12 })

      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    }
    .width('100%')
    .height('100%')
  }

  /** 导入密码库表单视图 */
  @Builder
  private ImportDatabaseFormView() {
    Column() {
      Column() {
        Text('导入外部密码库')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#000')
          .margin({ bottom: 20 })

        // 文件选择区域
        Column() {
          if (!this.importFilePath) {
            Image($r('app.media.icon'))
              .width(60)
              .height(60)
              .opacity(0.5)
              .margin({ bottom: 10 })

            Text('点击选择 .kdbx 文件')
              .fontSize(14)
              .fontColor('#666')
          } else {
            Image($r('app.media.success'))
              .width(40)
              .height(40)
              .fillColor('#52c41a')
              .margin({ bottom: 10 })

            Text(this.importFileName)
              .fontSize(14)
              .fontColor('#000')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('90%')
              .textAlign(TextAlign.Center)
          }
        }
        .width('100%')
        .height(120)
        .border({ width: 1, color: '#ddd', style: BorderStyle.Dashed })
        .borderRadius(8)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#f9f9f9')
        .margin({ bottom: 16 })
        .onClick(() => {
          this.pickDatabaseFile();
        })

        Row() {
          Button(this.importFilePath ? '重新选择文件' : '选择密码库文件')
            .onClick(() => {
              this.pickDatabaseFile();
            })
            .width('30%')
            .height(40)
            .fontSize(14)
            .backgroundColor('#007dff')
            .borderRadius(6)
            .margin({ right: 5 })

          Button('取消')
            .height(40)
            .fontSize(14)
            .backgroundColor('#f0f0f0')
            .fontColor('#000')
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .borderRadius(6)
            .onClick(() => {
              this.cancelImportDatabase();
            })
        }
        .width('100%')
        .margin({ bottom: 16 })

        if (this.importFilePath) {
          Column() {
            Text('主密码')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333')
              .margin({ bottom: 8 })
              .width('100%')
              .textAlign(TextAlign.Start)

            TextInput({ 
              text: this.importPassword, 
              placeholder: '请输入密码库的主密码' 
            })
              .type(InputType.Password)
              .onChange((val: string) => {
                this.importPassword = val;
              })
              .fontSize(16)
              .border({ width: 1, color: '#ddd' })
              .borderRadius(4)
              .padding(12)
              .width('100%')
          }
          .width('100%')
          .margin({ bottom: 16 })
          .alignItems(HorizontalAlign.Start)

          Row() {
            Button('导入密码库')
              .onClick(() => {
                this.confirmImportDatabase();
              })
              .width('40%')
              .height(45)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .backgroundColor('#52c41a')
              .borderRadius(8)
              .margin({ right: 10 })

            Button('取消')
              .onClick(() => {
                this.cancelImportDatabase();
              })
              .width('30%')
              .height(45)
              .fontSize(16)
              .backgroundColor('#f0f0f0')
              .fontColor('#666')
              .borderRadius(8)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 10 })
        }

        Column() {
          Text('说明')
            .fontSize(16)
            .fontColor('#333')
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 8 })

          Text('• 支持导入标准 KeePass (.kdbx) 格式的密码库文件\n• 文件可以从桌面、下载目录或其他位置选择\n• 密码库将被复制到应用内部存储中\n• 请确保输入正确的主密码\n• 仅支持 AES-KDF 密钥派生函数\n• 暂不支持 Argon2 密钥派生函数')
            .fontSize(14)
            .fontColor('#666')
            .lineHeight(20)
            .padding(12)
            .backgroundColor('#f9f9f9')
            .borderRadius(4)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 检查当前选中的密码库是否可以编辑（是否为当前打开的密码库）
   */
  private canEditSelectedDatabase(): boolean {
    if (!this.selectedDatabase) {
      return false;
    }
    
    const currentId = PreferencesUtil.getKdbxCurrentDatabaseIdSync();
    return this.selectedDatabase.id === currentId;
  }

  /**
   * 进入编辑模式
   */
  private enterEditMode() {
    if (!this.selectedDatabase) {
      return;
    }
    
    this.isEditing = true;
    this.editingName = this.selectedDatabase.name;
    this.editingPassword = '';
    this.confirmEditingPassword = '';
    
    if (this.formErrorTimer !== null) {
      clearTimeout(this.formErrorTimer);
      this.formErrorTimer = null;
    }
    this.formError = '';
  }

  /**
   * 取消编辑模式
   */
  private cancelEditMode() {
    this.isEditing = false;
    this.editingName = '';
    this.editingPassword = '';
    this.confirmEditingPassword = '';
    
    if (this.formErrorTimer !== null) {
      clearTimeout(this.formErrorTimer);
      this.formErrorTimer = null;
    }
    this.formError = '';
  }

  /**
   * 保存编辑内容
   */
  private async saveEditChanges() {
    if (!this.selectedDatabase) {
      return;
    }

    if (!this.editingName.trim()) {
      this.showFormError('密码库名称不能为空');
      return;
    }

    if (this.editingName.trim().length > 50) {
      this.showFormError('密码库名称不能超过50个字符');
      return;
    }

    const hasNewPassword = this.editingPassword.trim() !== '';
    if (hasNewPassword) {
      if (this.editingPassword.length < 8) {
        this.showFormError('主密码至少8位');
        return;
      }

      if (this.editingPassword !== this.confirmEditingPassword) {
        this.showFormError('两次密码不一致');
        return;
      }
    }

    try {
      const currentOriginalList: DatabaseItem[] = [];
      try {
        const listJson = PreferencesUtil.getKdbxDatabaseListSync();
        currentOriginalList.push(...JSON.parse(listJson) as DatabaseItem[]);
      } catch (e) {
        this.showFormError('获取密码库列表失败');
        return;
      }

      const currentItem = currentOriginalList.find(item => item.id === this.selectedDatabase!.id);
      if (!currentItem) {
        this.showFormError('找不到对应的密码库记录');
        return;
      }

      const newName = this.editingName.trim();

      if (hasNewPassword) {
        const currentKdbxCore = KdbxCoreManager.getInstance().getCurrentKdbxCore();
        if (!currentKdbxCore) {
          this.showFormError('当前没有打开的密码库实例');
          return;
        }

        const currentDb = currentKdbxCore.getDatabase();
        if (!currentDb) {
          this.showFormError('无法获取当前密码库数据');
          return;
        }

        if (!this.databaseFileManager) {
          this.showFormError('文件管理器未初始化');
          return;
        }

        try {
          const newCredentials = new KdbxCredentials(ProtectedValue.fromString(this.editingPassword));
          
          await newCredentials.ready;
          
          currentDb.credentials = newCredentials;
          
          if (currentDb.meta && currentDb.meta.name !== newName) {
            currentDb.meta.name = newName;
          }
          
          const fileSaveResult = await this.databaseFileManager.saveDatabaseToFile(
            currentDb,
            currentItem.path,
            true
          );

          if (!fileSaveResult.success) {
            this.showFormError('保存密码库文件失败');
            return;
          }

          const kdbxManager = KdbxCoreManager.getInstance();
          const currentCore = kdbxManager.getCurrentKdbxCore();
          if (currentCore) {
            currentCore.close(); 
          }
          kdbxManager.clearCurrentKdbxCore();
          
        } catch (error) {
          console.error('KdbxPage', '修改主密码失败:', error);
          this.showFormError('修改主密码失败');
          return;
        }
        
        currentItem.name = newName;
        PreferencesUtil.saveKdbxDatabaseListSync(JSON.stringify(currentOriginalList));
        
        this.successToastMessage = '密码库名称和主密码已更新，正在跳转...';
        this.showCopySuccessToast = true;
        
        setTimeout(async () => {
          this.showCopySuccessToast = false;
          try {
            await router.replaceUrl({
              url: 'pages/Index'
            });
          } catch (routerError) {
            console.error('KdbxPage', '跳转失败:', routerError);
            await router.back();
          }
        }, 2000);
        
        return; 
      }

      currentItem.name = newName;
      
      const currentKdbxCore = KdbxCoreManager.getInstance().getCurrentKdbxCore();
      let needSaveDatabaseForNameChange = false;
      
      if (currentKdbxCore) {
        const currentDb = currentKdbxCore.getDatabase();
        if (currentDb && currentDb.meta) {
          if (currentDb.meta.name !== newName) {
            currentDb.meta.name = newName;
            needSaveDatabaseForNameChange = true;
          }
        }
      }
      
      if (needSaveDatabaseForNameChange) {
        if (this.databaseFileManager && currentKdbxCore) {
          const currentDb = currentKdbxCore.getDatabase();
          if (currentDb) {
            try {
              const nameUpdateResult = await this.databaseFileManager.saveDatabaseToFile(
                currentDb,
                currentItem.path,
                true
              );
              
              if (!nameUpdateResult.success) {
                console.warn('KdbxPage', '更新密码库内部名称失败:', nameUpdateResult.error);
              }
            } catch (error) {
              console.warn('KdbxPage', '保存密码库内部名称时发生异常:', error);
            }
          }
        }
      }
      
      PreferencesUtil.saveKdbxDatabaseListSync(JSON.stringify(currentOriginalList));

      const ctxEdit = getContext(this) as Context;
      const updatedDisplayItem = convertToDisplayItem(currentItem, ctxEdit);
      const index = this.databaseItems.findIndex(item => item.id === this.selectedDatabase!.id);
      if (index !== -1) {
        const newDatabaseItems = [...this.databaseItems];
        newDatabaseItems[index] = updatedDisplayItem;
        this.databaseItems = newDatabaseItems;
      }

      this.selectedDatabase = {
        id: updatedDisplayItem.id,
        name: updatedDisplayItem.name,
        path: updatedDisplayItem.path,
        lastModified: updatedDisplayItem.lastModified,
        size: updatedDisplayItem.size,
        displayDir: updatedDisplayItem.displayDir,
        displayFileName: updatedDisplayItem.displayFileName,
        displaySize: updatedDisplayItem.displaySize
      };

      this.cancelEditMode();

      this.successToastMessage = '密码库名称已更新';
      this.showCopySuccessToast = true;
      
      if (this.copySuccessTimer !== null) {
        clearTimeout(this.copySuccessTimer);
      }
      this.copySuccessTimer = setTimeout(() => {
        this.showCopySuccessToast = false;
        this.copySuccessTimer = null;
      }, 2500);

    } catch (error) {
      console.error('KdbxPage', '保存编辑内容失败:', error);
      this.showFormError('保存时发生异常');
    }
  }

  build() {
    if (!this.isInitialized) {
      Column() {
        Text('正在初始化...')
          .fontSize(16)
          .fontColor('#666')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#f5f5f5')
    } else if (this.error) {
      Column() {
        Text(this.error)
          .fontSize(16)
          .fontColor('#ff4444')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 20 })

        Button('返回')
          .onClick(() => {
            this.onBackToMain()
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#f5f5f5')
    } else {
      Row() {
        if (!this.isFirstColumnCollapsed) {
          Column() {
            Row() {
              Image($r('app.media.down_arrow'))
                .width(16)
                .height(16)
                .fillColor('#666')
                .margin({ right: 8 })
                .onClick(() => {
                  this.onBackToMain()
                })
              
              Text('密码库管理')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#000')
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .onClick(() => {
                  this.onBackToMain()
                })

              Image($r('app.media.lock'))
                .width(20)
                .height(20)
                .fillColor('#666')
                .onClick(() => {
                  router.replaceUrl({
                    url: 'pages/Index'
                  })
                })
            }
            .width('100%')
            .height(50)
            .padding({ left: 16, right: 16 })
            .backgroundColor('#f8f9fa')
            .border({ width: { bottom: 1 }, color: '#e0e0e0' })

            if (this.isLoading) {
              Column() {
                LoadingProgress()
                  .width(40)
                  .height(40)
                  .color('#007AFF')
              }
              .width('100%')
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
              .backgroundColor('#fff')
            } else if (this.databaseItems.length === 0) {
              Column() {
                Image($r('app.media.startIcon'))
                  .width(60)
                  .height(60)
                  .opacity(0.3)
                  .margin({ bottom: 12 })

                Text('暂无密码库')
                  .fontSize(16)
                  .fontColor('#999')
                  
                Text('点击右上角创建新密码库')
                  .fontSize(14)
                  .fontColor('#ccc')
                  .margin({ top: 8 })
              }
              .width('100%')
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
              .backgroundColor('#fff')
            } else {
              Scroll() {
                Column() {
                  ForEach(this.databaseItems, (item: DisplayDatabaseItem) => {
                    Column() {
                      this.DatabaseItemView(item)
                      
                      Divider()
                        .strokeWidth(0.8)
                        .color('#e0e0e0')
                        .margin({ left: 16, right: 0 })
                    }
                  }, (item: DisplayDatabaseItem) => item.id)

                  Button() {
                    Row() {
                      Text('新增密码库')
                        .fontSize(16)
                        .fontColor('#007AFF')
                        .fontWeight(FontWeight.Medium)
                    }
                    .justifyContent(FlexAlign.Center)
                    .alignItems(VerticalAlign.Center)
                  }
                  .width('70%')
                  .height(32)
                  .backgroundColor('#f0f7ff')
                  .border({ width: 1, color: '#007AFF', style: BorderStyle.Dashed })
                  .borderRadius(6)
                  .margin({ left: 16, right: 16, top: 20, bottom: 8 })
                  .onClick(() => {
                    this.createNewDatabase();
                  })

                  Button() {
                    Row() {
                      Text('导入密码库')
                        .fontSize(16)
                        .fontColor('#52c41a')
                        .fontWeight(FontWeight.Medium)
                    }
                    .justifyContent(FlexAlign.Center)
                    .alignItems(VerticalAlign.Center)
                  }
                  .width('70%')
                  .height(32)
                  .backgroundColor('#f6ffed')
                  .border({ width: 1, color: '#52c41a', style: BorderStyle.Dashed })
                  .borderRadius(6)
                  .margin({ left: 16, right: 16, top: 8, bottom: 16 })
                  .onClick(() => {
                    this.selectDatabaseFile();
                  })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .justifyContent(FlexAlign.Start)
              }
              .width('100%')
              .layoutWeight(1)
              .backgroundColor('#fff')
              .align(Alignment.TopStart)
            }
            
            if (this.showSwitchSuccessToast) {
              Row() {
                Image($r('app.media.success'))
                  .width(16)
                  .height(16)
                  .fillColor('#52c41a')
                  .margin({ right: 8 })

                Text(this.switchSuccessMessage)
                  .fontSize(14)
                  .fontColor('#52c41a')
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .height(40)
              .padding({ left: 16, right: 16 })
              .backgroundColor('#f6ffed')
              .border({ width: { top: 1 }, color: '#b7eb8f' })
              .alignItems(VerticalAlign.Center)
              .justifyContent(FlexAlign.Center)
              .transition(TransitionEffect.opacity(1).animation({ duration: 300 }))
            }
          }
          .width(this.firstColumnWidth)
          .height('100%')
          .backgroundColor('#f8f9fa')
          .transition(TransitionEffect.translate({ x: -this.firstColumnWidth }).animation({ duration: 300, curve: Curve.EaseInOut }))

          Divider()
            .vertical(true)
            .color('#e0e0e0')
            .strokeWidth(3)
            .gesture(
              PanGesture({ direction: PanDirection.Horizontal, fingers: 1 })
                .onActionUpdate((event: GestureEvent) => {
                  let newFirstWidth = this.firstColumnWidth + event.offsetX
                  newFirstWidth = Math.max(200, Math.min(250, newFirstWidth))
                  this.firstColumnWidth = newFirstWidth
                })
                .onActionEnd(() => {
                  LayoutPreferencesUtil.saveFirstColumnWidth(this.firstColumnWidth)
                })
            )
        }

        Column() {
          Row() {
            Text(this.isAddingDatabase ? '创建密码库' : 
                 (this.isImportingDatabase ? '导入密码库' :
                  (this.isEditing ? `编辑密码库: ${this.editingName || this.selectedDatabase?.name || ''}` : 
                   (this.selectedDatabase ? this.selectedDatabase.name : '未选择密码库'))))
               .fontSize(18)
               .fontWeight(FontWeight.Medium)
               .fontColor('#000')
               .layoutWeight(1)
               .maxLines(1)
               .textOverflow({ overflow: TextOverflow.Ellipsis })

            if (!this.isAddingDatabase && !this.isImportingDatabase && this.canEditSelectedDatabase()) {
              Button() {
                Image($r('app.media.edit'))
                  .width(20)
                  .height(20)
                  .fillColor('#007AFF')
              }
              .backgroundColor('transparent')
              .padding(4)
              .stateEffect(false)
              .onClick(() => {
                if (this.selectedDatabase) {
                  this.enterEditMode();
                }
              })
            }
 
          }
          .width('100%')
          .height(50)
          .padding({ left: 16, right: 16 })
          .backgroundColor('#f8f9fa')
          .border({ width: { bottom: 1 }, color: '#e0e0e0' })

          Column() {
            if (this.isAddingDatabase) {
              this.CreateDatabaseFormView()
            } else if (this.isImportingDatabase) {
              this.ImportDatabaseFormView()
            } else if (this.isEditing) {
              this.EditPanelView()
            } else {
              this.InfoPanelView()
            }
          }
          .layoutWeight(1)
          .width('100%')
          .backgroundColor('#fff')
          .key(`content_panel_${this.selectedDatabase?.id || 'none'}_${this.isEditing ? 'edit' : (this.isImportingDatabase ? 'import' : 'view')}`)

          if (this.formError) {
            Row() {
              Text(this.formError)
                .fontSize(14)
                .fontColor('#ff4d4f')
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')
            .height(40)
            .padding({ left: 20, right: 20 })
            .backgroundColor('#fff1f0')
            .border({ width: { top: 1 }, color: '#ffa39e' })
            .alignItems(VerticalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .transition(TransitionEffect.opacity(1).animation({ duration: 300 }))
          } else if (this.showCopySuccessToast) {
            Row() {
              Image($r('app.media.success'))
                .width(16)
                .height(16)
                .fillColor('#52c41a')
                .margin({ right: 8 })

              Text(this.successToastMessage)
                .fontSize(14)
                .fontColor('#52c41a')
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')
            .height(40)
            .padding({ left: 20, right: 20 })
            .backgroundColor('#f6ffed')
            .border({ width: { top: 1 }, color: '#b7eb8f' })
            .alignItems(VerticalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .transition(TransitionEffect.opacity(1).animation({ duration: 300 }))
          }
        }
        .layoutWeight(1)
        .height('100%')
        .backgroundColor('#fff')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#e5e5e5')
    }
  }
} 