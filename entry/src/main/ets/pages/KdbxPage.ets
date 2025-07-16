import router from '@ohos.router'
import { common } from '@kit.AbilityKit'
import { DatabaseFileManager } from '../utils/DatabaseFileManager'
import PreferencesUtil from '../utils/PreferencesUtil'
import { LayoutPreferencesUtil } from '../utils/LayoutPreferencesUtil'
import fs from '@ohos.file.fs'
import DirtyFlag from '../utils/DirtyFlag'
import { KdbxCore, KdbxCoreManager } from '../utils/KdbxCore'
import { ProtectedValue, KdbxCredentials } from '../lib'
import { ClipboardUtil } from '../utils/ClipboardUtil'

// 密码库项目类型（配置项中的原始数据）
interface DatabaseItem {
  id: string
  name: string
  path: string
  lastModified: string
  size: number
}

// 页面显示用的密码库项目类型（包含转换后的显示信息）
interface DisplayDatabaseItem {
  id: string
  name: string
  path: string
  lastModified: string
  size: number
  // 转换后的显示字段
  displayDir: string
  displayFileName: string
  displaySize: string
}

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
  @State private isEditing: boolean = false // 编辑模式切换
  @State private hoverFieldKey: string | null = null // 悬停字段，用于显示复制按钮
  @State private showCopySuccessToast: boolean = false // 复制成功提示
  @State private successToastMessage: string = '复制成功'

  // 编辑状态
  @State private editingName: string = '' // 编辑中的密码库名称
  @State private editingPassword: string = '' // 编辑中的主密码
  @State private confirmEditingPassword: string = '' // 确认编辑中的主密码

  private copySuccessTimer: number | null = null
  private formErrorTimer: number | null = null

  @State private isAddingDatabase: boolean = false // 是否正在添加新密码库
  @State private newDbName: string = ''
  @State private newDbPath: string = ''
  @State private newPassword: string = ''
  @State private confirmPassword: string = ''
  @State private formError: string = ''
  @State private showSwitchSuccessToast: boolean = false // 切换密码库成功提示
  @State private switchSuccessMessage: string = '切换密码库成功'
  
  // 双击检测相关
  private lastClickTime: number = 0
  private lastClickedId: string = ''
  private readonly DOUBLE_CLICK_INTERVAL: number = 300 // 双击间隔时间(毫秒)

  async aboutToAppear() {
    try {
      // 获取应用上下文并初始化首选项
      const context = getContext(this) as Context
      
      // 尝试使用同步方法初始化
      let initialized = PreferencesUtil.initSync(context)
      if (!initialized) {
        initialized = await PreferencesUtil.init(context)
      }
      
      if (initialized) {
        const layout = await LayoutPreferencesUtil.restoreLayoutStates()
        this.isFirstColumnCollapsed = layout.collapsed
        this.firstColumnWidth = layout.firstWidth
      }
      
      // 初始化文件管理器
      this.databaseFileManager = new DatabaseFileManager(context)
      
      // 初始化数据
      await this.initializeData()
      
      this.isInitialized = true
    } catch (error) {
      this.error = `初始化失败: ${error}`
      this.isInitialized = true
    }
  }

  /**
   * 初始化数据
   */
  private async initializeData() {
    try {
      this.isLoading = true
      
      // 加载密码库列表
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

      // 优先从首选项读取密码库列表
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
            
            // 首先检查路径是否为空或无效
            if (!it.path || it.path.trim() === '') {
              exists = false;
            } else if (it.path.includes('/')) {
              // 绝对路径，直接检查
              await fs.access(it.path);
              const stat = await fs.stat(it.path);
              exists = stat.size > 0;
            } else if (this.databaseFileManager) {
              // 相对路径，通过 FileManager 检查
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

      // 将原始数据转换为页面显示数据
      this.databaseItems = validOriginalList.map(item => this.convertToDisplayItem(item));

      // 同步首选项，去除无效项（保存原始数据）
      PreferencesUtil.saveKdbxDatabaseListSync(JSON.stringify(validOriginalList));

      // 根据首选项恢复当前密码库选择
      const currentId: string = PreferencesUtil.getKdbxCurrentDatabaseIdSync();
      if (currentId) {
        const found = this.databaseItems.find(item => item.id === currentId);
        if (found) {
          this.selectedDatabaseId = found.id;
          // 创建新的对象引用以确保 UI 更新
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
   * 将原始密码库项目转换为页面显示项目
   */
  private convertToDisplayItem(item: DatabaseItem): DisplayDatabaseItem {
    // 使用 getDisplayPath 函数获取完整路径
    const fullPath = this.getDisplayPath(item)
    
    let displayDir = ''
    let displayFileName = item.path
    
    if (fullPath.includes('/')) {
      displayDir = fullPath.substring(0, fullPath.lastIndexOf('/'))
      displayFileName = fullPath.substring(fullPath.lastIndexOf('/') + 1)
    } else {
      displayDir = '应用数据目录'
      displayFileName = fullPath
    }
    
    let displaySize = ''
    if (item.size >= 1024 * 1024) {
      displaySize = `${(item.size / (1024 * 1024)).toFixed(2)} MB`
    } else if (item.size >= 1024) {
      displaySize = `${(item.size / 1024).toFixed(1)} KB`
    } else {
      displaySize = `${item.size} B`
    }
    
    return {
      id: item.id,
      name: item.name,
      path: item.path,
      lastModified: item.lastModified,
      size: item.size,
      displayDir,
      displayFileName,
      displaySize
    }
  }

  /**
   * 密码库项目点击处理 - 仅用于界面选中和查看信息，不改变当前使用的密码库
   */
  private onDatabaseItemClick(item: DisplayDatabaseItem) {
    const currentTime = Date.now()
    
    // 检测双击
    if (this.lastClickedId === item.id && 
        currentTime - this.lastClickTime < this.DOUBLE_CLICK_INTERVAL) {
      
      // 重置双击检测状态
      this.lastClickTime = 0
      this.lastClickedId = ''
      
      this.onDatabaseItemDoubleClick(item)
      return
    }
    
    // 更新双击检测状态
    this.lastClickTime = currentTime
    this.lastClickedId = item.id
    
    // 延迟执行单击逻辑，避免与双击冲突
    setTimeout(() => {
      // 检查是否在延迟期间发生了双击
      if (this.lastClickedId === item.id) {
        this.selectedDatabaseId = item.id
        // 创建新的对象引用以确保 UI 更新
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
        
        // 如果双击的就是当前密码库，不进行切换
        if (item.id === currentId) {
          return;
        }
        
        // 关闭并清除当前 KdbxCore 实例，下次将用新密码重新打开
        const kdbxManager = KdbxCoreManager.getInstance();
        const currentCore = kdbxManager.getCurrentKdbxCore();
        if (currentCore) {
        currentCore.close(); // 明确关闭数据库
                  }
          kdbxManager.clearCurrentKdbxCore(); // 清除实例引用
                
          // 设置双击的密码库为当前密码库
          PreferencesUtil.saveKdbxCurrentDatabaseIdSync(item.id);
        
        // 显示切换成功提示
        this.switchSuccessMessage = `已切换到: ${item.name}`;
        this.showSwitchSuccessToast = true;
      
      // 1秒后跳转回Index页面
      setTimeout(async () => {
        this.showSwitchSuccessToast = false;
        try {
          await router.replaceUrl({
            url: 'pages/Index'
          });
        } catch (routerError) {
          console.error('KdbxPage', '跳转失败:', routerError);
          // 如果replaceUrl失败，尝试使用back
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

  /**
   * 获取用于显示的密码库文件完整路径
   * 如果首选项中保存的 path 已经是绝对路径则直接返回；
   * 否则拼接 filesDir 形成完整路径，方便用户备份。
   */
  private getDisplayPath(db: DatabaseItem): string {
    if (!db || !db.path) {
      return '';
    }
    if (db.path.includes('/')) {
      // 如果是内部路径，尝试转换为外部可见路径 /storage/Users/currentUser/appdata/... 方便备份
      if (db.path.startsWith('/data/storage')) {
        try {
          const ctx = getContext(this) as common.UIAbilityContext;
          const bundleName: string = ((ctx as ESObject).bundleName as string) ?? 'com.mznm.hpassword';
          return db.path.replace('/data/storage', '/storage/Users/currentUser/appdata')
            .replace('/base/haps', `/base/${bundleName}/haps`);
        } catch(_) {
          // 转换失败时返回原始路径
          return db.path;
        }
      }
      return db.path;
    }
    try {
      const context = getContext(this) as Context;
      // 普通文件名，拼接内部 filesDir，再做一遍转换
      const internalPath = `${context.filesDir}/${db.path}`;
      if (internalPath.startsWith('/data/storage')) {
        try {
          const ctx = getContext(this) as common.UIAbilityContext;
          const bundleName: string = ((ctx as ESObject).bundleName as string) ?? 'com.mznm.hpassword';
          return internalPath.replace('/data/storage', '/storage/Users/currentUser/appdata')
            .replace('/base/haps', `/base/${bundleName}/haps`);
        } catch(_) {
          return internalPath;
        }
      }
      return internalPath;
    } catch (_) {
      return db.path;
    }
  }



  /** 复制文本到剪贴板并显示提示 */
  private async copyToClipboard(text: string): Promise<void> {
    try {
      await ClipboardUtil.copy(text)

      // 清除旧定时器
      if (this.copySuccessTimer !== null) {
        clearTimeout(this.copySuccessTimer)
        this.copySuccessTimer = null
      }

      this.successToastMessage = '复制成功'
      this.showCopySuccessToast = true

      // 2.5s 后隐藏
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
    // 清除旧定时器
    if (this.formErrorTimer !== null) {
      clearTimeout(this.formErrorTimer)
      this.formErrorTimer = null
    }

    this.formError = message

    // 3s 后隐藏错误提示
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
        // 详细信息字段
        Column() {
          // 密码库名称
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

          // 密码库路径
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

          // 密码库文件名
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

          // 最后修改
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

          // 大小
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

          Blank()
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 16 })
        .justifyContent(FlexAlign.Start)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
    } else {
      // 与 EditPanelView 中的空状态保持一致
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
        // 编辑内容
        Scroll() {
          Column() {
            // 编辑密码库
            Column() {
              Text('编辑密码库')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#000')
                .margin({ bottom: 16 })

              // 密码库名称
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

              // 新主密码（可选）
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

              // 确认主密码
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

              // 说明文字
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

            // 操作按钮
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

            // 占位符，撑满剩余空间
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
      // 空状态
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

  // 创建新密码库（示例实现：创建空记录并保存列表）
  private async createNewDatabase() {
    // 进入创建表单模式
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
    if (!this.isValidKdbxFileName(this.newDbPath.trim())) {
      this.showFormError('文件名仅允许英文、数字、下划线，且以 .kdbx 结尾');
      return;
    }

    try {
      const context = getContext(this) as Context;
      const fileNameOnly: string = this.newDbPath.trim();
      const finalPath: string = `${context.filesDir}/${fileNameOnly}`;

      // 检查文件是否已经存在
      let fileExists = false;
      try {
        if (fileNameOnly.includes('/')) {
          // 绝对路径，直接检查
          await fs.access(fileNameOnly);
          fileExists = true;
        } else {
          // 相对路径（文件名），通过 DatabaseFileManager 检查
          if (this.databaseFileManager) {
            fileExists = await this.databaseFileManager.fileExists(fileNameOnly);
          }
        }
        
        if (fileExists) {
          this.showFormError(`文件 ${fileNameOnly} 已存在，请使用其他文件名`);
          return;
        }
        
      } catch (error) {
        // 如果检查失败，为了安全起见，继续创建流程
      }

      // 使用 KdbxCore 创建密码库并加入两条测试条目
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

      // 保存密码库到文件
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
        path: fileNameOnly,  // 保存相对路径（只是文件名），与现有检查逻辑保持一致
        lastModified: new Date().toISOString().split('T')[0],
        size: size
      };

      // 获取现有的配置项列表并追加新密码库
      let currentOriginalList: DatabaseItem[] = [];
      try {
        const listJson = PreferencesUtil.getKdbxDatabaseListSync();
        currentOriginalList = JSON.parse(listJson) as DatabaseItem[];
      } catch (e) {
        currentOriginalList = [];
      }
      
      // 追加新密码库到配置项列表
      currentOriginalList.push(newOriginalItem);
      PreferencesUtil.saveKdbxDatabaseListSync(JSON.stringify(currentOriginalList));

      // 转换为显示项目并更新页面显示列表  
      const newDisplayItem = this.convertToDisplayItem(newOriginalItem);
      this.databaseItems.push(newDisplayItem);
      // 不自动切换当前使用的密码库，保持原有的密码库不变

      // 退出创建模式并选中新建的密码库（仅在界面上选中，不改变当前使用的密码库）
      this.isAddingDatabase = false;
      this.selectedDatabaseId = newId;
      // 创建新的对象引用以确保 UI 更新
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
    
    // 清除错误提示和定时器
    if (this.formErrorTimer !== null) {
      clearTimeout(this.formErrorTimer);
      this.formErrorTimer = null;
    }
    this.formError = '';
  }

  /** 新增密码库表单视图 */
  @Builder
  private CreateDatabaseFormView() {
    Column() {
      // 表单内容
      Column() {
        // 名称
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

        // 路径
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

        // 密码
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

        // 确认密码
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

        // 内联错误提示已移除，统一到底部Toast显示

        // 按钮行
        Row() {
          Button('创建新的密码库')
            .width('30%')
            .height(50)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#4CAF50')
            .borderRadius(8)
            .margin({ right: 5 })
            .onClick(() => {
              this.saveNewDatabase();
            })

          Button('取消')
            .height(50)
            .fontSize(16)
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

  private isValidKdbxFileName(fileName: string): boolean {
    const pattern: RegExp = /^[A-Za-z0-9_]+\.kdbx$/;
    return pattern.test(fileName);
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
    
    // 清除错误提示
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
    
    // 清除错误提示
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

    // 验证输入
    if (!this.editingName.trim()) {
      this.showFormError('密码库名称不能为空');
      return;
    }

    if (this.editingName.trim().length > 50) {
      this.showFormError('密码库名称不能超过50个字符');
      return;
    }

    // 如果设置了新密码，验证密码
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
      // 获取当前密码库的原始数据
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

      // 准备新的密码库名称
      const newName = this.editingName.trim();

      // 如果需要修改主密码，重新保存数据库文件
      if (hasNewPassword) {
        // 获取当前已经打开的密码库实例
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

        // 使用新密码创建新的凭据并保存
        if (!this.databaseFileManager) {
          this.showFormError('文件管理器未初始化');
          return;
        }

        try {
          // 创建新的凭据
          const newCredentials = new KdbxCredentials(ProtectedValue.fromString(this.editingPassword));
          
          // 等待凭据准备完成
          await newCredentials.ready;
          
          // 修改数据库的凭据
          currentDb.credentials = newCredentials;
          
          // 同时更新密码库内部的名称信息（如果有修改）
          if (currentDb.meta && currentDb.meta.name !== newName) {
            currentDb.meta.name = newName;
          }
          
          // 保存数据库到文件
          const fileSaveResult = await this.databaseFileManager.saveDatabaseToFile(
            currentDb,
            currentItem.path,
            true
          );

          if (!fileSaveResult.success) {
            this.showFormError('保存密码库文件失败');
            return;
          }

          // 关闭并清除当前 KdbxCore 实例，下次将用新密码重新打开
          const kdbxManager = KdbxCoreManager.getInstance();
          const currentCore = kdbxManager.getCurrentKdbxCore();
          if (currentCore) {
            currentCore.close(); // 明确关闭数据库
          }
          kdbxManager.clearCurrentKdbxCore(); // 清除实例引用
          
        } catch (error) {
          console.error('KdbxPage', '修改主密码失败:', error);
          this.showFormError('修改主密码失败');
          return;
        }
        
        // 修改密码成功后，更新配置项并跳转到 Index 页面
        // 不更新UI，因为马上就要跳转重新打开了
        currentItem.name = newName;
        PreferencesUtil.saveKdbxDatabaseListSync(JSON.stringify(currentOriginalList));
        
        // 显示成功提示并跳转
        this.successToastMessage = '密码库名称和主密码已更新，正在跳转...';
        this.showCopySuccessToast = true;
        
        // 2秒后跳转到Index页面
        setTimeout(async () => {
          this.showCopySuccessToast = false;
          try {
            await router.replaceUrl({
              url: 'pages/Index'
            });
          } catch (routerError) {
            console.error('KdbxPage', '跳转失败:', routerError);
            // 如果replaceUrl失败，尝试使用back
            await router.back();
          }
        }, 2000);
        
        return; // 提前返回，不执行后续的普通保存逻辑
      }

      // 以下是仅修改名称时的逻辑
      // 更新密码库名称
      currentItem.name = newName;
      
      // 同时更新密码库文件内部的名称信息
      const currentKdbxCore = KdbxCoreManager.getInstance().getCurrentKdbxCore();
      let needSaveDatabaseForNameChange = false;
      
      if (currentKdbxCore) {
        const currentDb = currentKdbxCore.getDatabase();
        if (currentDb && currentDb.meta) {
          // 检查内部名称是否需要更新
          if (currentDb.meta.name !== newName) {
            currentDb.meta.name = newName;
            needSaveDatabaseForNameChange = true;
          }
        }
      }
      
      // 如果修改了内部名称，需要保存数据库文件
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
                // 不阻止整个保存流程，只是记录警告
              }
            } catch (error) {
              console.warn('KdbxPage', '保存密码库内部名称时发生异常:', error);
              // 不阻止整个保存流程，只是记录警告
            }
          }
        }
      }
      
      // 更新配置项
      PreferencesUtil.saveKdbxDatabaseListSync(JSON.stringify(currentOriginalList));

      // 仅修改名称时：更新页面显示数据，刷新第一栏密码库列表UI
      const updatedDisplayItem = this.convertToDisplayItem(currentItem);
      const index = this.databaseItems.findIndex(item => item.id === this.selectedDatabase!.id);
      if (index !== -1) {
        // 创建新的 DisplayDatabaseItem 数组以触发ArkUI响应式更新
        const newDatabaseItems = [...this.databaseItems];
        newDatabaseItems[index] = updatedDisplayItem;
        this.databaseItems = newDatabaseItems;
      }

      // 更新选中的数据库对象
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

      // 退出编辑模式
      this.cancelEditMode();

      // 显示成功提示（此时只可能是名称修改，密码修改已在前面处理并跳转）
      this.successToastMessage = '密码库名称已更新';
      this.showCopySuccessToast = true;
      
      // 2.5秒后隐藏成功提示
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
      // 加载状态
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
      // 错误状态
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
      // 主界面
      Row() {
        // 第一栏：密码库列表
        if (!this.isFirstColumnCollapsed) {
          Column() {
            // 密码库列表标题
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
                  // 直接回到 Index 页面
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

            // 密码库列表
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
                  // 密码库列表项
                  ForEach(this.databaseItems, (item: DisplayDatabaseItem) => {
                    Column() {
                      this.DatabaseItemView(item)
                      
                      // 分割线
                      Divider()
                        .strokeWidth(0.8)
                        .color('#e0e0e0')
                        .margin({ left: 16, right: 0 })
                    }
                  }, (item: DisplayDatabaseItem) => item.id)

                  // 新增密码库按钮
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
                  .margin({ left: 16, right: 16, top: 20, bottom: 16 })
                  .onClick(() => {
                    this.createNewDatabase();
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
            
            // 切换密码库成功提示
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

          // 分割线
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

        // 第二栏：编辑面板
        Column() {
          // 编辑面板顶部工具栏
          Row() {
            Text(this.isAddingDatabase ? '创建密码库' : 
                 (this.isEditing ? `编辑密码库: ${this.editingName || this.selectedDatabase?.name || ''}` : 
                  (this.selectedDatabase ? this.selectedDatabase.name : '未选择密码库')))
               .fontSize(18)
               .fontWeight(FontWeight.Medium)
               .fontColor('#000')
               .layoutWeight(1)
               .maxLines(1)
               .textOverflow({ overflow: TextOverflow.Ellipsis })

            if (!this.isAddingDatabase && this.canEditSelectedDatabase()) {
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

          // 内容区域：根据状态切换显示
          Column() {
            if (this.isAddingDatabase) {
              this.CreateDatabaseFormView()
            } else if (this.isEditing) {
              this.EditPanelView()
            } else {
              this.InfoPanelView()
            }
          }
          .layoutWeight(1)
          .width('100%')
          .backgroundColor('#fff')
          .key(`content_panel_${this.selectedDatabase?.id || 'none'}_${this.isEditing ? 'edit' : 'view'}`)

          // 复制成功提示（第二栏底部）
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