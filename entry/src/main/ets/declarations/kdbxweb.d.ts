declare module 'kdbxweb' {
  /** 受保护的值，kdbxweb 原生类型简化声明 */
  export class ProtectedValue {
    static fromString(str: string): ProtectedValue;
    getText(): string;
  }

  export class KdbxCredentials {
    constructor(password?: ProtectedValue, keyFile?: ArrayBuffer);
  }

  export interface KdbxEntryFields {
    Title?: string;
    UserName?: string;
    Password?: ProtectedValue;
    [key: string]: any;
  }

  export interface KdbxEntry {
    fields: KdbxEntryFields;
  }

  export interface KdbxGroup {
    name: string;
    entries: KdbxEntry[];
    groups: KdbxGroup[];
  }

  export class Kdbx {
    static load(data: ArrayBuffer, creds: KdbxCredentials): Promise<Kdbx>;
    getDefaultGroup(): KdbxGroup;
  }
} 