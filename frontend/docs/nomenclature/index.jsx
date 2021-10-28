'use strict';

const React = require('react');
const Documents = require('./../documents/documents.jsx');

const styles = require('./styles');
const DOC_TYPE_ID = 'NOMENCLATURE';

/**
 * Класс реализует документ справочника признаков.
 */
class Nomenclatures extends React.PureComponent {
    constructor(props) {
        super(props);
        this.renderer = this.renderer.bind(this);
    }

    render() {
        return <Documents initData={this.props.initData}
                          history={this.props.history ? this.props.history : null}
                          ref='register'
                          module={this.props.module}
                          docTypeId={DOC_TYPE_ID}
                          style={styles}
                          render={this.renderer}/>;
    }

    renderer() {
        return null;
    }


}

module.exports = (Nomenclatures);


