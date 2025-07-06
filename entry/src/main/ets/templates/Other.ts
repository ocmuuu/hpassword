import { CategoryTemplate } from './TemplateTypes';

export const OtherTemplate: CategoryTemplate = {
  name: '其他',
  desc: '无法归类的杂项敏感信息，可自定义字段自由存储',
  fields: [
    { key: 'Title', label: '标题' },
    { key: 'Content', label: '内容' }
  ],
  samples: [
    {
      Title: '会议 Wi-Fi',
      Content: 'SSID: Conference\nPass: 2024welcome'
    }
  ]
}; 