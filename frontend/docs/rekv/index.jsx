'use strict';

const React = require('react');
const Documents = require('./../documents/documents.jsx');
const styles = require('./styles');
let DOC_TYPE_ID = 'REKV';

/**
 * Класс реализует документ справочника признаков.
 */
class Objects extends React.PureComponent {
    constructor(props) {
        super(props);
    }

    render() {
        return <Documents
            history={this.props.history ? this.props.history : null}
            module={this.props.module}
            ref='register'
            docTypeId={DOC_TYPE_ID}
            style={styles}
            render={this.renderer}/>;
    }

    renderer() {
        return null;
    }

}

module.exports = (Objects);


