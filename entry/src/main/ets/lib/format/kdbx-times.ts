import * as XmlNames from './../defs/xml-names';
import * as XmlUtils from './../utils/xml-utils';
import { KdbxContext } from './kdbx-context';

export class KdbxTimes {
    creationTime: Date | undefined;
    lastModTime: Date | undefined;
    lastAccessTime: Date | undefined;
    expiryTime: Date | undefined;
    expires: boolean | null | undefined;
    usageCount: number | undefined;
    locationChanged: Date | undefined;

    private readNode(node: any): void {
        switch (node.tagName) {
            case XmlNames.Elem.CreationTime:
                this.creationTime = XmlUtils.getDate(node);
                break;
            case XmlNames.Elem.LastModTime:
                this.lastModTime = XmlUtils.getDate(node);
                break;
            case XmlNames.Elem.LastAccessTime:
                this.lastAccessTime = XmlUtils.getDate(node);
                break;
            case XmlNames.Elem.ExpiryTime:
                this.expiryTime = XmlUtils.getDate(node);
                break;
            case XmlNames.Elem.Expires:
                this.expires = XmlUtils.getBoolean(node);
                break;
            case XmlNames.Elem.UsageCount:
                this.usageCount = XmlUtils.getNumber(node);
                break;
            case XmlNames.Elem.LocationChanged:
                this.locationChanged = XmlUtils.getDate(node);
                break;
        }
    }

    clone(): KdbxTimes {
        const clone = new KdbxTimes();
        clone.creationTime = this.creationTime;
        clone.lastModTime = this.lastModTime;
        clone.lastAccessTime = this.lastAccessTime;
        clone.expiryTime = this.expiryTime;
        clone.expires = this.expires;
        clone.usageCount = this.usageCount;
        clone.locationChanged = this.locationChanged;
        return clone;
    }

    update(): void {
        const now = new Date();
        this.lastModTime = now;
        this.lastAccessTime = now;
    }

    write(parentNode: any, ctx: KdbxContext): void {
        const node = XmlUtils.addChildNode(parentNode, XmlNames.Elem.Times);
        ctx.setXmlDate(XmlUtils.addChildNode(node, XmlNames.Elem.CreationTime), this.creationTime);
        ctx.setXmlDate(XmlUtils.addChildNode(node, XmlNames.Elem.LastModTime), this.lastModTime);
        ctx.setXmlDate(
            XmlUtils.addChildNode(node, XmlNames.Elem.LastAccessTime),
            this.lastAccessTime
        );
        ctx.setXmlDate(XmlUtils.addChildNode(node, XmlNames.Elem.ExpiryTime), this.expiryTime);
        XmlUtils.setBoolean(XmlUtils.addChildNode(node, XmlNames.Elem.Expires), this.expires);
        XmlUtils.setNumber(XmlUtils.addChildNode(node, XmlNames.Elem.UsageCount), this.usageCount);
        ctx.setXmlDate(
            XmlUtils.addChildNode(node, XmlNames.Elem.LocationChanged),
            this.locationChanged
        );
    }

    static create(): KdbxTimes {
        const times = new KdbxTimes();
        const now = new Date();
        times.creationTime = now;
        times.lastModTime = now;
        times.lastAccessTime = now;
        times.expiryTime = now;
        times.expires = false;
        times.usageCount = 0;
        times.locationChanged = now;
        return times;
    }

    static read(xmlNode: Node): KdbxTimes {
        const times = new KdbxTimes();
        const nodeAny = xmlNode as any;
        for (let i = 0, cn = nodeAny.childNodes, len = cn.length; i < len; i++) {
            const childNode = (cn[i] as any);
            if (childNode.tagName) {
                times.readNode(childNode);
            }
        }
        return times;
    }
}
