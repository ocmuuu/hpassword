import { CategoryTemplate } from './TemplateTypes';

export const AddressBookTemplate: CategoryTemplate = {
  name: '通信录',
  desc: '联系人姓名、电话、身份证及常用收货地址等个人信息',
  fields: [
    { key: 'Name', label: '姓名' },
    { key: 'Phone', label: '电话' },
    { key: 'Email', label: '邮箱' },
    { key: 'ID', label: '身份证号' },
    { key: 'Address', label: '地址' },
    { key: 'Company', label: '公司' },
    { key: 'JobTitle', label: '职位' },
    { key: 'Birthday', label: '生日' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Name: '张三',
      Phone: '13800001111',
      Email: 'zhangsan@example.com',
      ID: '110101199001011234',
      Address: '北京市朝阳区示例路 1 号',
      Company: '北京科技有限公司',
      JobTitle: '产品经理',
      Birthday: '1990-01-01',
      Notes: '家'
    }
  ]
}; 