'use strict';
const React = require('react');
const PropTypes = require('prop-types');

const DocContext = require('../../../doc-context');

const
    DocumentTemplate = require('./../../documentTemplate/index.jsx'),
    InputText = require('../../../components/input-text/input-text.jsx'),
    TextArea = require('../../../components/text-area/text-area.jsx'),
    styles = require('./asutused.styles');
const DataGrid = require('../../../components/data-grid/data-grid.jsx');
const Loading = require('./../../../components/loading/index.jsx');


class Asutused extends React.PureComponent {
    constructor(props) {
        super(props);
        this.state = {
            docId: props.docId ? props.docId : Number(props.match.params.docId),
            loadedData: false
        };

        this.renderer = this.renderer.bind(this);
    }

    render() {
        return <DocumentTemplate docId={this.state.docId}
                                 ref='document'
                                 history={this.props.history}
                                 module={DocContext.module}
                                 docTypeId='ASUTUSED'
                                 initData={this.props.initData}
                                 renderer={this.renderer}
                                 focusElement={'input-regkood'}

        />
    }

    renderer(self) {
        if (!self.docData || !self.docData.nimetus) {

            return (<div style={styles.doc}>
                <Loading label={'Laadimine...'}/>
            </div>);
        }


        let isEditeMode = self.state.edited;

        const gridUserData = self.docData.gridData,
            gridUserColumns = self.docData.gridConfig,
            gridObjectsData = self.docData.objects,
            gridObjectsColumns = self.docData.gridObjectsConfig;

        return (
            <div style={styles.doc}>
                <div style={styles.docRow}>
                    <div style={styles.docColumn}>
                        <InputText title="Reg.kood "
                                   name='regkood'
                                   ref="input-regkood"
                                   readOnly={!isEditeMode}
                                   value={self.docData.regkood || ''}
                                   onChange={self.handleInputChange}/>
                        <InputText title="Nimetus "
                                   name='nimetus'
                                   ref="input-nimetus"
                                   readOnly={!isEditeMode}
                                   value={self.docData.nimetus || ''}
                                   onChange={self.handleInputChange}/>
                        <InputText title="Om.vorm"
                                   name='omvorm'
                                   ref="input-omvorm"
                                   readOnly={!isEditeMode}
                                   value={self.docData.omvorm || ''}
                                   onChange={self.handleInputChange}/>
                        <InputText title="Arveldus arve:"
                                   name='aa'
                                   ref="input-aa"
                                   readOnly={!isEditeMode}
                                   value={self.docData.aa || ''}
                                   onChange={self.handleInputChange}/>
                    </div>
                </div>
                <div style={styles.docRow}>
                    <TextArea title="Aadress"
                              name='aadress'
                              ref="textarea-aadress"
                              onChange={self.handleInputChange}
                              value={self.docData.aadress || ''}
                              readOnly={!isEditeMode}/>
                </div>
                <div style={styles.docRow}>
                    <TextArea title="Kontakt"
                              name='kontakt'
                              ref="textarea-kontakt"
                              onChange={self.handleInputChange}
                              value={self.docData.kontakt || ''}
                              readOnly={!isEditeMode}/>
                </div>
                <div style={styles.docRow}>
                    <InputText title="Telefon"
                               name='tel'
                               ref="input-tel"
                               value={self.docData.tel || ''}
                               readOnly={!isEditeMode}
                               onChange={self.handleInputChange}/>
                </div>
                <div style={styles.docRow}>
                    <InputText title="Email"
                               name='email'
                               ref="input-email"
                               value={self.docData.email || ''}
                               readOnly={!isEditeMode}
                               onChange={self.handleInputChange}/>
                </div>
                <div style={styles.docRow}>
                    <TextArea title="Muud"
                              name='muud'
                              ref="textarea-muud"
                              onChange={self.handleInputChange}
                              value={self.docData.muud || ''}
                              readOnly={!isEditeMode}/>
                </div>
                <div style={styles.docRow}>
                    <TextArea title="Märkused"
                              name='mark'
                              ref="textarea-mark"
                              onChange={self.handleInputChange}
                              value={self.docData.mark || ''}
                              readOnly={!isEditeMode}/>
                </div>
                <div style={styles.docRow}>
                    <label ref="label">
                        {'Kasutaja objektid'}
                    </label>
                </div>
                <div style={styles.docRow}>

                    <DataGrid source='objects'
                              gridData={gridObjectsData}
                              gridColumns={gridObjectsColumns}
                              showToolBar={false}
                              readOnly={true}
                              style={styles.grid.headerTable}
                              docTypeId={'object'}
                              ref="objects-data-grid"/>
                </div>
                <div style={styles.docRow}>
                    <label ref="label">
                        {'Kasutaja andmed'}
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

Asutused.propTypes = {
    docId: PropTypes.number,
    initData: PropTypes.object,
    userData: PropTypes.object
};

Asutused.defaultProps = {
    initData: {},
    userData: {}
};

module.exports = (Asutused);
