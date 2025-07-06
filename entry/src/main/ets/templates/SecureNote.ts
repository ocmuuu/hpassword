import { CategoryTemplate } from './TemplateTypes';

export const SecureNoteTemplate: CategoryTemplate = {
  name: '安全笔记',
  desc: '用于保存任何希望加密存储的纯文本内容，例如门禁码、密保答案或快捷备注',
  fields: [
    { key: 'Title', label: '标题' },
    { key: 'Notes', label: '内容' }
  ],
  samples: [
    {
      Title: '小区门禁码',
      Notes: '东门：2580#\n西门：1470#'
    }
  ]
}; 