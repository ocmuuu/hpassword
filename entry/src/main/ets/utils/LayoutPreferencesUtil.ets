import PreferencesUtil from './PreferencesUtil'

// 布局状态接口
export interface LayoutState {
  collapsed: boolean
  firstWidth: number
  secondWidth: number
}

/**
 * 布局与首选项相关工具
 */
export class LayoutPreferencesUtil {
  /**
   * 恢复布局状态（第一栏折叠 & 宽度、第二栏宽度）
   */
  static async restoreLayoutStates(): Promise<LayoutState> {
    let collapsed = false
    let firstWidth = 200
    let secondWidth = 250

    try {
      if (!PreferencesUtil.isInitialized()) {
        return { collapsed, firstWidth, secondWidth } as LayoutState
      }

      collapsed = PreferencesUtil.getKdbxFirstColumnCollapseStateSync()
      const savedFirstWidth = PreferencesUtil.getKdbxFirstColumnWidthSync()
      const savedSecondWidth = PreferencesUtil.getKdbxSecondColumnWidthSync()

      if (savedFirstWidth >= 200 && savedFirstWidth <= 250) {
        firstWidth = savedFirstWidth
      }
      if (savedSecondWidth >= 250 && savedSecondWidth <= 350) {
        secondWidth = savedSecondWidth
      }
    } catch (e) {
      console.error('LayoutPreferencesUtil', 'restoreLayoutStates error:', e)
    }

    return { collapsed, firstWidth, secondWidth } as LayoutState
  }

  static saveFirstColumnCollapseState(collapsed: boolean) {
    if (PreferencesUtil.isInitialized()) {
      PreferencesUtil.saveKdbxFirstColumnCollapseStateSync(collapsed)
    }
  }

  static saveFirstColumnWidth(width: number) {
    if (PreferencesUtil.isInitialized()) {
      PreferencesUtil.saveKdbxFirstColumnWidthSync(width)
    }
  }

  static saveSecondColumnWidth(width: number) {
    if (PreferencesUtil.isInitialized()) {
      PreferencesUtil.saveKdbxSecondColumnWidthSync(width)
    }
  }

  /**
   * 启动/复位自动关闭计时器
   * @returns 新的 timer id
   */
  static startAutoCloseTimer(
    currentTimer: number | null,
    timeout: number,
    callback: () => void
  ): number {
    if (currentTimer !== null) {
      clearTimeout(currentTimer)
    }
    return setTimeout(callback, timeout)
  }

  /** 清除自动关闭计时器 */
  static clearAutoCloseTimer(currentTimer: number | null): void {
    if (currentTimer !== null) {
      clearTimeout(currentTimer)
    }
  }
} 