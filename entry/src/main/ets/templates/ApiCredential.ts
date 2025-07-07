import { CategoryTemplate } from './TemplateTypes';

export const ApiCredentialTemplate: CategoryTemplate = {
  name: 'API 凭据',
  desc: '第三方服务的 API Key/Secret，用于程序化访问接口',
  fields: [
    { key: 'Title', label: '服务名称' },
    { key: 'Key', label: 'API Key' },
    { key: 'Secret', label: 'API Secret', protected: true },
    { key: 'BaseURL', label: '基础URL' },
    { key: 'Documentation', label: '文档链接' },
    { key: 'RateLimit', label: '速率限制' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: 'OpenAI',
      Key: 'sk-xxxxxxxxxxxx',
      Secret: '********',
      BaseURL: 'https://api.openai.com/v1',
      Documentation: 'https://platform.openai.com/docs',
      RateLimit: '3 RPM',
      Notes: '账户邮箱: me@example.com'
    }
  ]
}; 