import { api, LightningElement } from 'lwc';

// The options use the same codes as Apex (AFD_PrepareReturnQuoteAction.REASONS)
const REASONS = [
    { value: 'DEFECT', label: 'Defective or damaged' },
    { value: 'WRONG_ITEM', label: 'Received the wrong item' },
    { value: 'SIZE', label: 'Wrong size or specifications' },
    { value: 'CHANGED_MIND', label: 'Changed my mind' }
];

// Return request form (editor for c__returnRequestForm).
// Input comes from a form, not from the LLM asking questions. Values go back to the parent (the Agentforce conversation) through valuechange.
export default class AfdReturnRequestForm extends LightningElement {
    @api readOnly = false;
    _value;
    @api
    get value() { return this._value; }
    set value(v) {
        this._value = v;
        if (v) {
            this.orderNumber = v.orderNumber || '';
            this.emailTail4 = v.emailTail4 || '';
            this.reasonCode = v.reasonCode || '';
            this.unopened = v.unopened === true;
        }
    }
    orderNumber = '';
    emailTail4 = '';
    reasonCode = '';
    unopened = false;

    reasons = REASONS;

    handleChange(event) {
        event.stopPropagation();
        const { name } = event.target;
        this[name] = event.target.type === 'toggle' || event.target.type === 'checkbox'
            ? event.target.checked : event.detail.value;
        this.notify();
    }

    notify() {
        this.dispatchEvent(new CustomEvent('valuechange', {
            detail: { value: {
                orderNumber: this.orderNumber, emailTail4: this.emailTail4,
                reasonCode: this.reasonCode, unopened: this.unopened
            } }
        }));
    }
}
