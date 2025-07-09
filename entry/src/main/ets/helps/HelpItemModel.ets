export default class HelpItemModel {
  readonly id: string
  readonly title: string
  readonly icon: Resource
  readonly content: string

  constructor(id: string, title: string, icon: Resource, content: string) {
    this.id = id
    this.title = title
    this.icon = icon
    this.content = content
  }
} 