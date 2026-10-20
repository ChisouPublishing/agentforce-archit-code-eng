import { api, LightningElement } from 'lwc';

const usd = (n) => (n === null || n === undefined) ? '—' : Number(n).toLocaleString('en-US', { style: 'currency', currency: 'USD' });

// Return quote (renderer for c__returnQuote). Shows the amount and eligibility exactly as Apex decided them.
export default class AfdReturnQuoteCard extends LightningElement {
    @api value;

    get ok() { return this.value?.verified === true && this.value?.eligible === true; }
    get orderNumber() { return this.value?.orderNumber || '—'; }
    get orderDate() { return this.value?.orderDate || null; }
    get reasonLabel() { return this.value?.reasonLabel || '—'; }
    get refundAmount() { return this.value?.refundAmount ?? 0; }
    get verifiedLabel() { return this.value?.verified ? 'Verified' : 'Not verified'; }
    get routeLabel() {
        return this.value?.needsApproval
            ? 'Confirming creates an approval request (approval takes 1-2 business days)'
            : 'Confirming submits a refund request';
    }
    get message() { return this.value?.message || ''; }
    get noticeClass() {
        return `slds-scoped-notification slds-m-top_small ${this.ok ? 'slds-scoped-notification_light' : 'slds-theme_warning'}`;
    }
    get noticeIcon() { return this.ok ? 'utility:info' : 'utility:warning'; }

    // Global copy: the copy button passes the quote as a table
    @api
    getFormattedValue() {
        const rows = [['Order Number', this.orderNumber], ['Order Date', this.orderDate || '—'], ['Return Reason', this.reasonLabel],
            ['Expected Refund', this.ok ? usd(this.refundAmount) : '—'], ['Next Step', this.ok ? this.routeLabel : '—']];
        const cell = 'border:1px solid #c9c9c9;padding:4px 8px';
        return `<table style="border-collapse:collapse">${rows.map(([k, v]) =>
            `<tr><th style="${cell};background:#f3f3f3;text-align:left">${k}</th><td style="${cell}">${v}</td></tr>`).join('')}</table>`;
    }
}
