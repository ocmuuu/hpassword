import router from '@ohos.router'
import { common } from '@kit.AbilityKit'
import { DatabaseFileManager } from '../utils/DatabaseFileManager'
import PreferencesUtil from '../utils/PreferencesUtil'
import pasteboard from '@ohos.pasteboard'
import fs from '@ohos.file.fs'

// 数据库项目类型
interface DatabaseItem {
  id: string
  name: string
  path: string
  lastModified: string
  size: number
}

@Entry
@Component
struct KdbxPage {
  // 数据状态
  @State private databaseItems: DatabaseItem[] = []
  @State private selectedDatabaseId: string | null = null
  @State private selectedDatabase: DatabaseItem | null = null
  
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
  @State private isEditing: boolean = false // 预留编辑模式切换，目前默认只读
  @State private hoverFieldKey: string | null = null // 悬停字段，用于显示复制按钮
  @State private showCopySuccessToast: boolean = false // 复制成功提示
  @State private successToastMessage: string = '复制成功'

  private copySuccessTimer: number | null = null

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
        // 恢复布局状态
        await this.restoreLayoutStates()
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
   * 恢复布局状态
   */
  private async restoreLayoutStates() {
    try {
      if (!PreferencesUtil.isInitialized()) {
        return
      }

      // 恢复第一栏折叠状态
      this.isFirstColumnCollapsed = PreferencesUtil.getKdbxFirstColumnCollapseStateSync()
      
      // 恢复列宽度
      const savedFirstWidth = PreferencesUtil.getKdbxFirstColumnWidthSync()
      
      if (savedFirstWidth >= 200 && savedFirstWidth <= 250) {
        this.firstColumnWidth = savedFirstWidth
      }
      
    } catch (error) {
      console.error('KdbxPage', '恢复布局状态失败:', error)
    }
  }

  /**
   * 初始化数据
   */
  private async initializeData() {
    try {
      this.isLoading = true
      
      // 加载数据库列表
      await this.loadDatabaseList()
      
    } catch (error) {
      this.error = `数据初始化失败: ${error}`
    } finally {
      this.isLoading = false
    }
  }

  /**
   * 加载数据库列表
   */
  private async loadDatabaseList() {
    try {
      if (!this.databaseFileManager) {
        return
      }

      // 优先从首选项读取数据库列表
      const listJson: string = PreferencesUtil.getKdbxDatabaseListSync();
      let storedList: DatabaseItem[] = [];
      try {
        storedList = JSON.parse(listJson) as DatabaseItem[];
      } catch (e) {
        console.error('KdbxPage', '解析数据库列表失败:', e);
      }

      let validList: DatabaseItem[] = [];
      if (storedList && storedList.length > 0) {
        const existenceArr: boolean[] = await Promise.all(storedList.map(async (it: DatabaseItem) => {
          try {
            if (it.path.includes('/')) {
              await fs.access(it.path);
              const stat = await fs.stat(it.path);
              return stat.size > 0;
            } else if (this.databaseFileManager) {
              return await this.databaseFileManager.fileExists(it.path);
            }
          } catch(_) {
            return false;
          }
          return false;
        }));
        validList = storedList.filter((_, idx) => existenceArr[idx]);
      }

      // 更新数据库列表
      this.databaseItems = validList;

      // 同步首选项，去除无效项
      PreferencesUtil.saveKdbxDatabaseListSync(JSON.stringify(validList));

      // 根据首选项恢复当前数据库选择
      const currentId: string = PreferencesUtil.getKdbxCurrentDatabaseIdSync();
      if (currentId) {
        const found = this.databaseItems.find(item => item.id === currentId);
        if (found) {
          this.selectedDatabaseId = found.id;
          this.selectedDatabase = found;
        }
      }
       
    } catch (error) {
      console.error('KdbxPage', '加载数据库列表失败:', error)
    }
  }

  /**
   * 数据库项目点击处理
   */
  private onDatabaseItemClick(item: DatabaseItem) {
    this.selectedDatabaseId = item.id
    this.selectedDatabase = item

    // 保存当前选择到首选项
    PreferencesUtil.saveKdbxCurrentDatabaseIdSync(item.id)
  }

  /**
   * 切换第一栏折叠状态
   */
  private onToggleFirstColumn() {
    this.isFirstColumnCollapsed = !this.isFirstColumnCollapsed
    
    // 保存状态
    if (PreferencesUtil.isInitialized()) {
      PreferencesUtil.saveKdbxFirstColumnCollapseStateSync(this.isFirstColumnCollapsed)
    }
  }

  /**
   * 根据数据库项返回对应的图标资源
   * - 当前使用的数据库（保存在首选项中）使用 select.png
   * - 当前列表选中的数据库使用 selecte.png
   * - 其他数据库使用 unselecte.png
   */
  private getDatabaseIconRes(item: DatabaseItem): Resource {
    const currentId: string = PreferencesUtil.getKdbxCurrentDatabaseIdSync();
    if (item.id === currentId) {
      return $r('app.media.select');
    }
    if (item.id === this.selectedDatabaseId) {
      return $r('app.media.select');
    }
    return $r('app.media.unselect');
  }

  /**
   * 获取用于显示的数据库文件完整路径
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

  private getDisplayDir(db: DatabaseItem): string {
    const fullPath: string = this.getDisplayPath(db);
    const idx: number = fullPath.lastIndexOf('/')
    return idx !== -1 ? fullPath.substring(0, idx) : fullPath;
  }

  private getFileName(db: DatabaseItem): string {
    const fullPath: string = this.getDisplayPath(db);
    const idx: number = fullPath.lastIndexOf('/')
    return idx !== -1 ? fullPath.substring(idx + 1) : fullPath;
  }

  /** 复制文本到剪贴板并显示提示 */
  private async copyToClipboard(text: string): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
      const sysPb = pasteboard.getSystemPasteboard()
      await sysPb.setData(data)

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
   * 数据库信息查看面板
   */
  @Builder
  private InfoPanelView() {
    if (this.selectedDatabase) {
      Column() {
        // 详细信息字段
        Column() {
          this.DetailFieldView('数据库名称', this.selectedDatabase.name)
          this.DetailFieldView('数据库路径', this.getDisplayDir(this.selectedDatabase))
          this.DetailFieldView('数据库文件名', this.getFileName(this.selectedDatabase))
          this.DetailFieldView('最后修改', this.selectedDatabase.lastModified)
          this.DetailFieldView('大小', `${(this.selectedDatabase.size / 1024).toFixed(1)} KB`)

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

          Text('选择一个数据库查看信息')
            .fontSize(16)
            .fontColor('#999')

          Text('从左侧列表中选择要查看的数据库')
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
   * 创建数据库项目视图
   */
  @Builder
  private DatabaseItemView(item: DatabaseItem) {
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
            // 基本信息
            Column() {
              Text('基本信息')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#000')
                .margin({ bottom: 16 })

              // 数据库名称
              Column() {
                Text('数据库名称')
                  .fontSize(16)
                  .fontColor('#333')
                  .fontWeight(FontWeight.Medium)
                  .margin({ bottom: 8 })

                TextInput({ 
                  placeholder: '请输入数据库名称',
                  text: this.selectedDatabase.name
                })
                  .fontSize(16)
                  .border({ width: 1, color: '#ddd' })
                  .borderRadius(4)
                  .padding(12)
              }
              .width('100%')
              .margin({ bottom: 16 })
              .alignItems(HorizontalAlign.Start)

              // 数据库路径
              Column() {
                Text('数据库路径')
                  .fontSize(16)
                  .fontColor('#333')
                  .fontWeight(FontWeight.Medium)
                  .margin({ bottom: 8 })

                TextInput({ 
                  placeholder: '请输入数据库路径',
                  text: this.selectedDatabase.path
                })
                  .fontSize(16)
                  .border({ width: 1, color: '#ddd' })
                  .borderRadius(4)
                  .padding(12)
              }
              .width('100%')
              .margin({ bottom: 16 })
              .alignItems(HorizontalAlign.Start)

              // 描述
              Column() {
                Text('描述')
                  .fontSize(16)
                  .fontColor('#333')
                  .fontWeight(FontWeight.Medium)
                  .margin({ bottom: 8 })

                TextArea({ 
                  placeholder: '请输入数据库描述'
                })
                  .fontSize(16)
                  .border({ width: 1, color: '#ddd' })
                  .borderRadius(4)
                  .padding(12)
                  .height(80)
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
                .backgroundColor('#6FA8FF')
                .fontColor('#fff')
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .borderRadius(4)
                .border({ width: 1, color: '#000' })
                .margin({ right: 8 })

              Button('重置')
                .fontSize(14)
                .backgroundColor('#f0f0f0')
                .fontColor('#666')
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .borderRadius(4)
                .border({ width: 1, color: '#000' })
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

          Text('选择一个数据库进行编辑')
            .fontSize(16)
            .fontColor('#999')

          Text('从左侧列表中选择要编辑的数据库')
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

  // 创建新数据库（示例实现：创建空记录并保存列表）
  private async createNewDatabase() {
    try {
      // 生成简单 ID 和默认名称
      const newId = Date.now().toString();
      const newName = `密码库_${this.databaseItems.length + 1}`;
      const newPath = `${newName}.kdbx`;

      const newItem: DatabaseItem = {
        id: newId,
        name: newName,
        path: newPath,
        lastModified: new Date().toISOString().split('T')[0],
        size: 0
      };

      // 更新列表
      this.databaseItems = [...this.databaseItems, newItem];

      // 保存到首选项
      PreferencesUtil.saveKdbxDatabaseListSync(JSON.stringify(this.databaseItems));
      PreferencesUtil.saveKdbxCurrentDatabaseIdSync(newId);

      // 更新界面选择
      this.selectedDatabaseId = newId;
      this.selectedDatabase = newItem;

    } catch (e) {
      console.error('KdbxPage', '创建新数据库失败:', e);
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
        // 第一栏：数据库列表
        if (!this.isFirstColumnCollapsed) {
          Column() {
            // 数据库列表标题
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

            // 数据库列表
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

                Text('暂无数据库')
                  .fontSize(16)
                  .fontColor('#999')
                  
                Text('点击右上角创建新数据库')
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
                  // 数据库列表项
                  ForEach(this.databaseItems, (item: DatabaseItem) => {
                    Column() {
                      this.DatabaseItemView(item)
                      
                      // 分割线
                      Divider()
                        .strokeWidth(0.8)
                        .color('#e0e0e0')
                        .margin({ left: 16, right: 0 })
                    }
                  }, (item: DatabaseItem) => item.id)

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
                  .margin({ left: 16, right: 16, top: 8, bottom: 16 })
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
                  if (PreferencesUtil.isInitialized()) {
                    PreferencesUtil.saveKdbxFirstColumnWidthSync(this.firstColumnWidth)
                  }
                })
            )
        }

        // 第二栏：编辑面板
        Column() {
          // 编辑面板顶部工具栏
          Row() {
            Text(this.selectedDatabase ? this.selectedDatabase.name : '未选择密码库')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor('#000')
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Button() {
              Image($r('app.media.edit'))
                .width(20)
                .height(20)
                .fillColor(this.selectedDatabase ? '#007AFF' : '#CCCCCC')
            }
            .backgroundColor('transparent')
            .padding(4)
            .stateEffect(false)
            .opacity(this.selectedDatabase ? 1 : 0.4)
            .onClick(() => {
              if (this.selectedDatabase) {
                // TODO: 进入编辑模式或弹出编辑对话框
                console.log('KdbxPage', '编辑数据库', this.selectedDatabase.name)
              }
            })
          }
          .width('100%')
          .height(50)
          .padding({ left: 16, right: 16 })
          .backgroundColor('#f8f9fa')
          .border({ width: { bottom: 1 }, color: '#e0e0e0' })

          // 内容区域：默认查看信息
          Column() {
            this.InfoPanelView()
          }
          .layoutWeight(1)
          .width('100%')
          .backgroundColor('#fff')

          // 复制成功提示（第二栏底部）
          if (this.showCopySuccessToast) {
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