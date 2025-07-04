import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { readKdbxFromRawFile, ResourceManager, RawFileEntry } from '../utils/KdbxReader';
import resourceManager from '@ohos.resourceManager';

// 适配器类，解决 ArkTS 对象字面量限制
class RawFileEntryAdapter implements RawFileEntry {
  private rm: resourceManager.ResourceManager;
  private name: string;

  constructor(rm: resourceManager.ResourceManager, name: string) {
    this.rm = rm;
    this.name = name;
  }

  openRawFile(): Promise<ArrayBuffer> {
    hilog.info(0, 'RawFileEntryAdapter', '开始读取 rawfile: %{public}s', this.name);
    return this.rm.getRawFileContent(this.name).then((buffer: Uint8Array) => {
      hilog.info(0, 'RawFileEntryAdapter', 'rawfile 读取成功，大小: %{public}d bytes', buffer.byteLength);
      return buffer.buffer;
    }).catch((err: Error) => {
      const errorMsg: string = err.message || 'Unknown error';
      hilog.error(0, 'RawFileEntryAdapter', 'rawfile 读取失败: %{public}s', errorMsg);
      throw new Error(`Failed to read rawfile: ${errorMsg}`);
    });
  }
}

class ResourceManagerAdapter implements ResourceManager {
  private rm: resourceManager.ResourceManager;

  constructor(rm: resourceManager.ResourceManager) {
    this.rm = rm;
  }

  getRawFileEntry(name: string): Promise<RawFileEntry> {
    hilog.info(0, 'ResourceManagerAdapter', '创建 RawFileEntry: %{public}s', name);
    return Promise.resolve(new RawFileEntryAdapter(this.rm, name));
  }
}

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');

    hilog.info(DOMAIN, 'testTag', '=== 开始初始化 KDBX 读取 ===');
    // 调用 rawfile 读取示例 (文件位于 entry/src/main/resources/rawfile/testdatabase.kdbx)
    const rm = this.context.resourceManager;
    hilog.info(DOMAIN, 'testTag', 'ResourceManager 获取成功: %{public}s', rm ? 'true' : 'false');
    
    const adaptedRm = new ResourceManagerAdapter(rm);
    hilog.info(DOMAIN, 'testTag', 'ResourceManagerAdapter 创建成功');
    
    hilog.info(DOMAIN, 'testTag', '开始调用 readKdbxFromRawFile...');
    readKdbxFromRawFile(adaptedRm, 'testdatabase.kdbx', 'testdatabase').then(() => {
      hilog.info(DOMAIN, 'testTag', 'readKdbxFromRawFile 执行完成');
    }).catch((err: Error) => {
      const errorMsg: string = err.message || 'Unknown error';
      hilog.error(DOMAIN, 'testTag', 'readKdbxFromRawFile 执行失败: %{public}s', errorMsg);
    });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}