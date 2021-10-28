'use strict';

const React = require('react');
const Documents = require('./../documents/documents.jsx');
const styles = require('./asutus-register-styles');
//const gridConfig = require('./../../../models/libs/libraries/asutused').grid.gridConfiguration;

const DOC_TYPE_ID = 'ASUTUSED';


/**
 * Класс реализует документ справочника признаков.
 */
class Asutused extends React.PureComponent {
    constructor(props) {
        super(props);
        this.handleClick = this.handleClick.bind(this);
        this.renderer = this.renderer.bind(this);

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

    /**
     * кастомный обработчик события клик на кнопку импорта
     */
    handleClick(result) {

        //обновим данные
        const Doc = this.refs['register'];
        if (!Doc) {
            return null;
        }
        if (result) {
            Doc.setState({warning: `Edukalt:  ${result}: `, warningType: 'ok'});
            setTimeout(() => {
                Doc.fetchData('selectDocs');
            }, 10000);
        }
    }


}

module.exports = (Asutused);


