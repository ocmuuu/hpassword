import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';

export default class PreferencesUtil {
  private static initialized: boolean = false;
  private static dataPreferences: preferences.Preferences | null = null;

  /**
   * 同步初始化，真实场景可替换为PreferenceManager等持久化实现。
   */
  static initSync(context: Object): boolean {
    try {
      // 同步初始化preferences
      PreferencesUtil.dataPreferences = preferences.getPreferencesSync(context as Context, { name: 'hPassword_settings.db' });
      PreferencesUtil.initialized = true;
      return true;
    } catch (err) {
      console.error('PreferencesUtil', 'Failed to get preferences sync', err);
      return false;
    }
  }

  /**
   * 异步初始化（兼容原异步调用）。
   */
  static async init(context: Object): Promise<boolean> {
    try {
      PreferencesUtil.dataPreferences = await preferences.getPreferences(context as Context, 'hPassword_settings.db');
      PreferencesUtil.initialized = true;
      return true;
    } catch (err) {
      console.error('PreferencesUtil', 'Failed to get preferences', err);
      return false;
    }
  }

  static isInitialized(): boolean {
    return PreferencesUtil.initialized;
  }

  // region Getter
  static getKdbxFirstColumnCollapseStateSync(): boolean {
    return PreferencesUtil.dataPreferences?.getSync('kdbx_first_column_collapsed', false) as boolean ?? false;
  }

  static getKdbxFirstColumnWidthSync(): number {
    return PreferencesUtil.dataPreferences?.getSync('kdbx_first_column_width', 200) as number ?? 200;
  }

  static getKdbxSecondColumnWidthSync(): number {
    return PreferencesUtil.dataPreferences?.getSync('kdbx_second_column_width', 250) as number ?? 250;
  }
  // endregion

  // region Setter
  static saveSelectedKdbxSidebarIdSync(id: string): void {
    if (PreferencesUtil.dataPreferences) {
      PreferencesUtil.dataPreferences.putSync('kdbx_selected_sidebar_id', id);
      PreferencesUtil.dataPreferences.flush();
    }
  }

  static saveKdbxFirstColumnCollapseStateSync(state: boolean): void {
    if (PreferencesUtil.dataPreferences) {
      PreferencesUtil.dataPreferences.putSync('kdbx_first_column_collapsed', state);
      PreferencesUtil.dataPreferences.flush();
    }
  }

  static saveKdbxFirstColumnWidthSync(width: number): void {
    if (PreferencesUtil.dataPreferences) {
      PreferencesUtil.dataPreferences.putSync('kdbx_first_column_width', width);
      PreferencesUtil.dataPreferences.flush();
    }
  }

  static saveKdbxSecondColumnWidthSync(width: number): void {
    if (PreferencesUtil.dataPreferences) {
      PreferencesUtil.dataPreferences.putSync('kdbx_second_column_width', width);
      PreferencesUtil.dataPreferences.flush();
    }
  }
  // endregion
} 