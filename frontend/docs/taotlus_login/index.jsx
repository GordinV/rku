'use strict';

const React = require('react');
const Documents = require('./../documents/documents.jsx');
const styles = require('./styles');
const DOC_TYPE_ID = 'TAOTLUS_LOGIN';
const TOOLBAR_PROPS = require('./../../../config/constants').TEATIS.toolbarProps;


/**
 * Класс реализует документ справочника признаков.
 */
class Register extends React.PureComponent {
    constructor(props) {
        super(props);
    }

    render() {
        return <Documents initData={this.props.initData}
                          history={this.props.history ? this.props.history : null}
                          module={this.props.module}
                          ref='register'
                          docTypeId={DOC_TYPE_ID}
                          style={styles}
                          toolbarProps={TOOLBAR_PROPS}
                          render={this.renderer}/>;
    }

    renderer() {
        return null;
    }
}


module.exports = (Register);


