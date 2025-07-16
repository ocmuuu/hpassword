import pasteboard from '@ohos.pasteboard'

export class ClipboardUtil {
  /** 将文本复制到系统剪贴板 */
  static async copy(text: string): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
      const sys = pasteboard.getSystemPasteboard()
      await sys.setData(data)
      console.log('ClipboardUtil', '复制成功:', text.substring(0, 20))
    } catch (e) {
      console.error('ClipboardUtil', '复制失败', e)
      throw new Error((e as Error)?.message ?? 'copy error')
    }
  }
} 