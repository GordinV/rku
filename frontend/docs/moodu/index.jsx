'use strict';

const React = require('react');
const DocumentRegister = require('./../documents/documents.jsx');
const styles = require('./styles');

/**
 * Класс реализует документ справочника признаков.
 */
class Documents extends React.PureComponent {
    constructor(props) {
        super(props);
        this.renderer = this.renderer.bind(this);

    }

    render() {
        let DOC_TYPE_ID = this.props.module == 'kasutaja' ? 'ISIKU_ANDMED' : 'ANDMED';

        return (
            <div>
                <DocumentRegister initData={this.props.initData}
                                  history={this.props.history ? this.props.history : null}
                                  module={this.props.module}
                                  ref='register'
                                  docTypeId={DOC_TYPE_ID}
                                  style={styles}
                                  render={this.renderer}/>
            </div>
        );
    }

    renderer(self) {
        return null;
    }

}


module.exports = (Documents);


