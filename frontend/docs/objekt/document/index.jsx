'use strict';
const React = require('react');
const PropTypes = require('prop-types');

const DocumentTemplate = require('./../../documentTemplate/index.jsx'),
    TextArea = require('../../../components/text-area/text-area.jsx'),
    Loading = require('./../../../components/loading/index.jsx');
const DataGrid = require('../../../components/data-grid/data-grid.jsx');

const styles = require('./styles');

/**
 * Класс реализует документ справочника признаков.
 */
class Objekt extends React.PureComponent {
    constructor(props) {
        super(props);

        this.state = {
            docId: props.docId ? props.docId : Number(props.match.params.docId),
            loadedData: false
        };
        this.renderer = this.renderer.bind(this);
    }

    render() {
        return (
            <DocumentTemplate docId={this.state.docId}
                              ref='document'
                              docTypeId='OBJEKT'
                              module={this.props.module}
                              initData={this.props.initData}
                              userData={this.props.userData}
                              renderer={this.renderer}
                              focusElement={'input-aadress'}
                              history={this.props.history}

            />
        )
    }

    /**
     * Метод вернет кастомный компонент
     * @param self
     * @returns {*}
     */
    renderer(self) {
        if (!self.docData) {
            // не загружены данные
            return (<div style={styles.doc}>
                <Loading label={'Laadimine...'}/>
            </div>);
        }

        const gridUserData = self.docData.gridData,
            gridUserColumns = self.docData.gridConfig;

        return (
            <div style={styles.doc}>
                <div style={styles.docRow}>
                    <TextArea title="Aadress"
                              name='aadress'
                              ref="textarea-aadress"
                              onChange={self.handleInputChange}
                              value={self.docData.aadress || ''}
                              readOnly={!self.state.edited}/>
                </div>
                <div style={styles.docRow}>
                    <TextArea title="Muud"
                              name='muud'
                              ref="textarea-muud"
                              onChange={self.handleInputChange}
                              value={self.docData.muud || ''}
                              readOnly={!self.state.edited}/>
                </div>
                <br/>
                <div style={styles.docRow}>
                    <label ref="label">
                        {'Objekti kasutajad'}
                    </label>
                </div>

                <div style={styles.docRow}>
                    <DataGrid source='userid'
                              gridData={gridUserData}
                              gridColumns={gridUserColumns}
                              showToolBar={false}
                              readOnly={true}
                              style={styles.grid.headerTable}
                              docTypeId={'userid'}
                              ref="userid-data-grid"/>
                </div>

            </div>
        );
    }

}

Objekt.propTypes = {
    docId: PropTypes.number,
    initData: PropTypes.object
};

Objekt.defaultProps = {
    initData: {},
};


module.exports = (Objekt);
