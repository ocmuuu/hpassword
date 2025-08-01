import { CategoryTemplate } from './TemplateTypes';

export const CertificateTemplate: CategoryTemplate = {
  name: '证件证照',
  desc: '身份证、护照、职业资格证等官方证件的编号、发证机关及有效期信息',
  fields: [
    { key: 'Title', label: '证件名称' },
    { key: 'HolderName', label: '持有人姓名' },
    { key: 'Number', label: '证件号码' },
    { key: 'Type', label: '证件类型' },
    { key: 'IssueDate', label: '签发日期' },
    { key: 'ExpiryDate', label: '有效期' },
    { key: 'Issuer', label: '签发机关' },
    { key: 'Nationality', label: '国籍' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: '张三的身份证',
      HolderName: '张三',
      Number: '110101199001011234',
      Type: '身份证',
      IssueDate: '2015-05-20',
      ExpiryDate: '2035-05-20',
      Issuer: '北京市公安局',
      Nationality: '中华人民共和国'
    }
  ]
}; 