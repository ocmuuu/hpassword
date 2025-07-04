// polyfills.ts - 提供lib库所需的全局API实现

// 定义全局对象
const globalObj = globalThis as any;

// TextEncoder polyfill
if (!globalObj.TextEncoder) {
  globalObj.TextEncoder = class TextEncoder {
    encode(input: string = ''): Uint8Array {
      const utf8: number[] = [];
      for (let i = 0; i < input.length; i++) {
        let charcode = input.charCodeAt(i);
        if (charcode < 0x80) utf8.push(charcode);
        else if (charcode < 0x800) {
          utf8.push(0xc0 | (charcode >> 6), 0x80 | (charcode & 0x3f));
        } else if (charcode < 0xd800 || charcode >= 0xe000) {
          utf8.push(0xe0 | (charcode >> 12), 0x80 | ((charcode >> 6) & 0x3f), 0x80 | (charcode & 0x3f));
        } else {
          i++;
          charcode = 0x10000 + (((charcode & 0x3ff) << 10) | (input.charCodeAt(i) & 0x3ff));
          utf8.push(0xf0 | (charcode >> 18), 0x80 | ((charcode >> 12) & 0x3f), 0x80 | ((charcode >> 6) & 0x3f), 0x80 | (charcode & 0x3f));
        }
      }
      return new Uint8Array(utf8);
    }
  };
}

// TextDecoder polyfill
if (!globalObj.TextDecoder) {
  globalObj.TextDecoder = class TextDecoder {
    private encoding: string;
    
    constructor(encoding: string = 'utf-8') {
      this.encoding = encoding;
    }
    
    decode(input: ArrayBuffer | Uint8Array = new Uint8Array()): string {
      const bytes = input instanceof ArrayBuffer ? new Uint8Array(input) : input;
      let result = '';
      let i = 0;
      
      while (i < bytes.length) {
        let byte1 = bytes[i++];
        if (byte1 < 0x80) {
          result += String.fromCharCode(byte1);
        } else if ((byte1 & 0xe0) === 0xc0) {
          let byte2 = bytes[i++];
          result += String.fromCharCode(((byte1 & 0x1f) << 6) | (byte2 & 0x3f));
        } else if ((byte1 & 0xf0) === 0xe0) {
          let byte2 = bytes[i++];
          let byte3 = bytes[i++];
          result += String.fromCharCode(((byte1 & 0x0f) << 12) | ((byte2 & 0x3f) << 6) | (byte3 & 0x3f));
        } else if ((byte1 & 0xf8) === 0xf0) {
          let byte2 = bytes[i++];
          let byte3 = bytes[i++];
          let byte4 = bytes[i++];
          let codepoint = ((byte1 & 0x07) << 18) | ((byte2 & 0x3f) << 12) | ((byte3 & 0x3f) << 6) | (byte4 & 0x3f);
          codepoint -= 0x10000;
          result += String.fromCharCode((codepoint >> 10) + 0xd800, (codepoint & 0x3ff) + 0xdc00);
        }
      }
      
      return result;
    }
  };
}

// Base64 polyfills
if (!globalObj.atob) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
  
  globalObj.atob = function(input: string): string {
    let str = input.replace(/=+$/, '');
    let output = '';
    
    if (str.length % 4 == 1) {
      throw new Error('Invalid base64 string');
    }
    
    for (let bc = 0, bs = 0, buffer, i = 0; (buffer = str.charAt(i++));) {
      buffer = chars.indexOf(buffer);
      if (buffer < 0) continue;
      bs = bc % 4 ? bs * 64 + buffer : buffer;
      if (bc++ % 4) output += String.fromCharCode(255 & bs >> (-2 * bc & 6));
    }
    
    return output;
  };
}

if (!globalObj.btoa) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
  
  globalObj.btoa = function(input: string): string {
    let str = input;
    let output = '';
    
    for (let block = 0, charCode, i = 0, map = chars; str.charAt(i | 0) || (map = '=', i % 1); output += map.charAt(63 & block >> 8 - i % 1 * 8)) {
      charCode = str.charCodeAt(i += 3/4);
      if (charCode > 0xFF) {
        throw new Error('Invalid character');
      }
      block = block << 8 | charCode;
    }
    
    return output;
  };
}

// Buffer polyfill - 不继承Uint8Array，避免类型冲突
if (!globalObj.Buffer) {
  globalObj.Buffer = class Buffer {
    private data: Uint8Array;
    
    constructor(input?: number | string | ArrayBuffer | Uint8Array | number[]) {
      if (typeof input === 'number') {
        this.data = new Uint8Array(input);
      } else if (typeof input === 'string') {
        const encoder = new globalObj.TextEncoder();
        this.data = encoder.encode(input);
      } else if (input instanceof ArrayBuffer) {
        this.data = new Uint8Array(input);
      } else if (input instanceof Uint8Array) {
        this.data = new Uint8Array(input);
      } else if (Array.isArray(input)) {
        this.data = new Uint8Array(input);
      } else {
        this.data = new Uint8Array(0);
      }
    }
    
    static from(data: string | ArrayBuffer | Uint8Array | number[], encoding?: string): Buffer {
      return new Buffer(data);
    }
    
    static alloc(size: number): Buffer {
      return new Buffer(size);
    }
    
    toString(encoding: string = 'utf8'): string {
      const decoder = new globalObj.TextDecoder();
      return decoder.decode(this.data);
    }
    
    get buffer(): ArrayBuffer {
      return this.data.buffer;
    }
    
    get byteLength(): number {
      return this.data.byteLength;
    }
    
    get byteOffset(): number {
      return this.data.byteOffset;
    }
    
    get length(): number {
      return this.data.length;
    }
  };
}

// global 对象指向 globalThis
if (!globalObj.global) {
  globalObj.global = globalObj;
}

// require函数的简化实现
if (!globalObj.require) {
  globalObj.require = function(id: string): any {
    if (id === '@xmldom/xmldom') {
      return {
        DOMParser: globalObj.DOMParser,
        XMLSerializer: globalObj.XMLSerializer
      };
    }
    throw new Error(`require('${id}') not implemented in polyfill`);
  };
}

// DOM API 的简化实现
class SimpleNode {
  nodeType: number = 1;
  nodeName: string = '';
  nodeValue: string | null = null;
  parentNode: SimpleNode | null = null;
  childNodes: SimpleNode[] = [];
  textContent: string | null = null;
  nextSibling: SimpleNode | null = null;
  
  appendChild(child: SimpleNode): SimpleNode {
    this.childNodes.push(child);
    child.parentNode = this;
    // 更新兄弟节点关系
    if (this.childNodes.length > 1) {
      this.childNodes[this.childNodes.length - 2].nextSibling = child;
    }
    return child;
  }
  
  insertBefore(newChild: SimpleNode, refChild: SimpleNode | null): SimpleNode {
    if (refChild) {
      const index = this.childNodes.indexOf(refChild);
      if (index >= 0) {
        this.childNodes.splice(index, 0, newChild);
      }
    } else {
      this.childNodes.push(newChild);
    }
    newChild.parentNode = this;
    // 更新兄弟节点关系
    this.updateSiblings();
    return newChild;
  }
  
  private updateSiblings(): void {
    for (let i = 0; i < this.childNodes.length; i++) {
      const current = this.childNodes[i];
      current.nextSibling = i < this.childNodes.length - 1 ? this.childNodes[i + 1] : null;
    }
  }
}

class SimpleElement extends SimpleNode {
  tagName: string = '';
  attributes: Map<string, string> = new Map();
  ownerDocument: SimpleDocument | null = null;
  
  constructor(tagName: string = '', ownerDocument: SimpleDocument | null = null) {
    super();
    this.tagName = tagName;
    this.nodeName = tagName;
    this.ownerDocument = ownerDocument;
  }
  
  getAttribute(name: string): string | null {
    return this.attributes.get(name) || null;
  }
  
  setAttribute(name: string, value: string): void {
    this.attributes.set(name, value);
  }
  
  removeAttribute(name: string): void {
    this.attributes.delete(name);
  }
  
  getElementsByTagName(tagName: string): SimpleElement[] {
    const result: SimpleElement[] = [];
    if (this.tagName === tagName) {
      result.push(this);
    }
    for (const child of this.childNodes) {
      if (child instanceof SimpleElement) {
        result.push(...child.getElementsByTagName(tagName));
      }
    }
    return result;
  }
}

class SimpleDocument extends SimpleNode {
  documentElement: SimpleElement | null = null;
  TEXT_NODE: number = 3;
  PROCESSING_INSTRUCTION_NODE: number = 7;
  
  createElement(tagName: string): SimpleElement {
    const element = new SimpleElement(tagName, this);
    return element;
  }
  
  createTextNode(data: string): SimpleNode {
    const node = new SimpleNode();
    node.nodeType = 3; // TEXT_NODE
    node.textContent = data;
    node.nodeValue = data;
    return node;
  }
  
  getElementsByTagName(tagName: string): SimpleElement[] {
    const result: SimpleElement[] = [];
    if (this.documentElement) {
      result.push(...this.documentElement.getElementsByTagName(tagName));
    }
    return result;
  }
}

class SimpleDOMParser {
  parseFromString(xmlString: string, mimeType: string): SimpleDocument {
    const doc = new SimpleDocument();
    
    // 简化的XML解析器 - 仅支持基本的XML结构
    try {
      const parser = this.createSimpleParser(xmlString, doc);
      doc.documentElement = parser.root;
      return doc;
    } catch (e) {
      // 创建一个包含错误信息的文档
      const errorDoc = new SimpleDocument();
      const errorElement = new SimpleElement('parsererror', errorDoc);
      errorElement.textContent = e instanceof Error ? e.message : String(e);
      errorDoc.documentElement = errorElement;
      return errorDoc;
    }
  }
  
  private createSimpleParser(xmlString: string, doc: SimpleDocument) {
    // 移除XML声明
    xmlString = xmlString.replace(/<\?xml[^>]*\?>/g, '');
    
    // 简化的标签解析
    const tagRegex = /<(\/?)([\w:]+)([^>]*)>/g;
    const stack: SimpleElement[] = [];
    let root: SimpleElement | null = null;
    let currentPos = 0;
    let match;
    
    while ((match = tagRegex.exec(xmlString)) !== null) {
      const isClosing = match[1] === '/';
      const tagName = match[2];
      const attributes = match[3];
      
      // 处理标签之间的文本内容
      if (match.index > currentPos) {
        const textContent = xmlString.substring(currentPos, match.index);
        if (textContent.trim() && stack.length > 0) {
          const textNode = doc.createTextNode(textContent.trim());
          const parentElement = stack[stack.length - 1];
          parentElement.appendChild(textNode);
          // 设置父元素的textContent
          parentElement.textContent = textContent.trim();
        }
      }
      
      if (isClosing) {
        // 闭合标签
        if (stack.length > 0 && stack[stack.length - 1].tagName === tagName) {
          stack.pop();
        }
      } else {
        // 开始标签
        const element = new SimpleElement(tagName, doc);
        
        // 解析属性
        if (attributes) {
          const attrRegex = /(\w+)=["']([^"']*)["']/g;
          let attrMatch;
          while ((attrMatch = attrRegex.exec(attributes)) !== null) {
            element.setAttribute(attrMatch[1], attrMatch[2]);
          }
        }
        
        if (stack.length > 0) {
          stack[stack.length - 1].appendChild(element);
        } else {
          root = element;
        }
        
        // 检查是否是自闭合标签
        if (!attributes.endsWith('/')) {
          stack.push(element);
        }
      }
      
      currentPos = tagRegex.lastIndex;
    }
    
    // 处理最后的文本内容
    if (currentPos < xmlString.length) {
      const textContent = xmlString.substring(currentPos);
      if (textContent.trim() && stack.length > 0) {
        const textNode = doc.createTextNode(textContent.trim());
        const parentElement = stack[stack.length - 1];
        parentElement.appendChild(textNode);
        // 设置父元素的textContent
        parentElement.textContent = textContent.trim();
      }
    }
    
    return { root };
  }
}

class SimpleXMLSerializer {
  serializeToString(node: SimpleNode): string {
    if (node instanceof SimpleDocument) {
      return this.serializeNode(node.documentElement);
    }
    return this.serializeNode(node);
  }
  
  private serializeNode(node: SimpleNode | null): string {
    if (!node) return '';
    
    if (node.nodeType === 3) { // TEXT_NODE
      return node.textContent || '';
    }
    
    if (node instanceof SimpleElement) {
      let result = `<${node.tagName}`;
      
      // 添加属性
      for (const [name, value] of node.attributes) {
        result += ` ${name}="${value}"`;
      }
      
      if (node.childNodes.length === 0) {
        result += '/>';
      } else {
        result += '>';
        for (const child of node.childNodes) {
          result += this.serializeNode(child);
        }
        result += `</${node.tagName}>`;
      }
      
      return result;
    }
    
    // 处理其他节点类型
    let result = '';
    for (const child of node.childNodes) {
      result += this.serializeNode(child);
    }
    return result;
  }
}

// 添加DOM API到全局对象
if (!globalObj.Document) {
  globalObj.Document = SimpleDocument;
}

if (!globalObj.Element) {
  globalObj.Element = SimpleElement;
}

if (!globalObj.Node) {
  globalObj.Node = SimpleNode;
}

if (!globalObj.DOMParser) {
  globalObj.DOMParser = SimpleDOMParser;
}

if (!globalObj.XMLSerializer) {
  globalObj.XMLSerializer = SimpleXMLSerializer;
}

// Crypto API polyfill
if (!globalObj.crypto) {
  globalObj.crypto = {
    getRandomValues: function(array: Uint8Array | Uint16Array | Uint32Array): any {
      // 使用Math.random()作为fallback随机数生成器
      // 注意：这不是密码学安全的，仅用于开发和测试
      for (let i = 0; i < array.length; i++) {
        if (array instanceof Uint8Array) {
          array[i] = Math.floor(Math.random() * 256);
        } else if (array instanceof Uint16Array) {
          array[i] = Math.floor(Math.random() * 65536);
        } else if (array instanceof Uint32Array) {
          array[i] = Math.floor(Math.random() * 4294967296);
        }
      }
      return array;
    }
  };
}

export {}; // 确保这是一个模块 