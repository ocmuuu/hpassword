export default class PreferencesUtil {
  private static initialized: boolean = false;
  private static store: Map<string, Object | boolean | number | string> = new Map();

  /**
   * 同步初始化，真实场景可替换为PreferenceManager等持久化实现。
   */
  static initSync(_context: Object): boolean {
    // 这里仅作占位实现，标记已初始化
    PreferencesUtil.initialized = true;
    return PreferencesUtil.initialized;
  }

  /**
   * 异步初始化（兼容原异步调用）。
   */
  static async init(_context: Object): Promise<boolean> {
    PreferencesUtil.initialized = true;
    return PreferencesUtil.initialized;
  }

  static isInitialized(): boolean {
    return PreferencesUtil.initialized;
  }

  // region Getter
  static getKdbxFirstColumnCollapseStateSync(): boolean {
    return (PreferencesUtil.store.get('kdbx_first_column_collapsed') as boolean) ?? false;
  }

  static getKdbxFirstColumnWidthSync(): number {
    return (PreferencesUtil.store.get('kdbx_first_column_width') as number) ?? 250;
  }

  static getKdbxSecondColumnWidthSync(): number {
    return (PreferencesUtil.store.get('kdbx_second_column_width') as number) ?? 350;
  }
  // endregion

  // region Setter
  static saveSelectedKdbxSidebarIdSync(id: string): void {
    PreferencesUtil.store.set('kdbx_selected_sidebar_id', id);
  }

  static saveKdbxFirstColumnCollapseStateSync(state: boolean): void {
    PreferencesUtil.store.set('kdbx_first_column_collapsed', state);
  }

  static saveKdbxFirstColumnWidthSync(width: number): void {
    PreferencesUtil.store.set('kdbx_first_column_width', width);
  }

  static saveKdbxSecondColumnWidthSync(width: number): void {
    PreferencesUtil.store.set('kdbx_second_column_width', width);
  }
  // endregion
} 