import PreferencesUtil from './PreferencesUtil'

/**
 * 全局自动关闭/锁定管理器。
 * 统一负责超时逻辑，避免各页面各自维护计时器。
 */
export class AutoCloseManager {
  private static readonly _instance = new AutoCloseManager()

  /** 默认超时时间：10 分钟 */
  private readonly TIMEOUT = 10 * 60 * 1000

  private timerId: number | null = null
  private lastActive: number = Date.now()
  private callback: (() => void) | null = null

  /** 单例访问 */
  public static getInstance(): AutoCloseManager {
    return AutoCloseManager._instance
  }

  private constructor() {}

  /**
   * 初始化超时回调，一般在应用进入主页面后调用一次。
   */
  public init(cb: () => void): void {
    this.callback = cb
    // 若首选项已持久化最后活跃时间，则加载
    let saved = 0
    if (PreferencesUtil.isInitialized() && typeof PreferencesUtil.getLastActiveTimeSync === 'function') {
      saved = PreferencesUtil.getLastActiveTimeSync()
    }

    if (saved > 0) {
      this.lastActive = saved
    }

    this.resume()
  }

  /** 用户交互重置 */
  public reset(): void {
    this.lastActive = Date.now()
    // 持久化
    if (PreferencesUtil.isInitialized() && typeof PreferencesUtil.saveLastActiveTimeSync === 'function') {
      PreferencesUtil.saveLastActiveTimeSync(this.lastActive)
    }
    this.schedule(this.TIMEOUT)
  }

  /** 进入后台暂停计时，但保存最后活跃时间 */
  public pause(): void {
    this.clear()
    if (PreferencesUtil.isInitialized() && typeof PreferencesUtil.saveLastActiveTimeSync === 'function') {
      PreferencesUtil.saveLastActiveTimeSync(this.lastActive)
    }
  }

  /** 回到前台后继续计时，必要时直接触发回调 */
  public resume(): void {
    const diff = Date.now() - this.lastActive
    if (diff >= this.TIMEOUT) {
      this.trigger()
    } else {
      this.schedule(this.TIMEOUT - diff)
    }
  }

  /** 清除现有计时器 */
  public clear(): void {
    if (this.timerId !== null) {
      clearTimeout(this.timerId)
      this.timerId = null
    }
  }

  // 内部：触发回调
  private trigger(): void {
    this.clear()
    this.callback?.()
  }

  // 内部：重新排定计时器
  private schedule(delay: number): void {
    this.clear()
    this.timerId = setTimeout(this.trigger.bind(this), delay)
  }
} 