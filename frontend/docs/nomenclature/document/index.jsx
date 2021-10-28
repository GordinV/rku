'use strict';
const React = require('react');
const PropTypes = require('prop-types');

const
    DocumentTemplate = require('./../../documentTemplate/index.jsx'),
    InputText = require('../../../components/input-text/input-text.jsx'),
    InputDate = require('../../../components/input-date/input-date.jsx'),
    Select = require('../../../components/select/select.jsx'),
    TextArea = require('../../../components/text-area/text-area.jsx'),
    InputNumber = require('../../../components/input-number/input-number.jsx'),
    styles = require('./styles');

const {LIBRARIES, TAXIES, UHIK} = require('./../../../../config/constants').NOMENCLATURE;


class Nomenclature extends React.PureComponent {
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
                                 docTypeId='NOMENCLATURE'
                                 module={this.props.module}
                                 initData={this.props.initData}
                                 history={this.props.history}
                                 userData={this.props.userData}
                                 libs={LIBRARIES}
                                 renderer={this.renderer}
                                 focusElement={'input-kood'}
        />
    }

    /**
     * Метод вернет кастомный компонент
     * @param self инстенс базавого документа
     * @returns {*}
     */
    renderer(self) {
        if (!self.docData) {
            return null;
        }

        let isEditeMode = self.state.edited;

        return (
            <div>
                <div style={styles.doc}>
                    <div style={styles.docRow}>
                        <div style={styles.docColumn}>
                            <InputText title="Kood "
                                       name='kood'
                                       ref="input-kood"
                                       value={self.docData.kood}
                                       onChange={self.handleInputChange}/>
                            <InputText title="Nimetus "
                                       name='nimetus'
                                       ref="input-nimetus"
                                       value={self.docData.nimetus}
                                       onChange={self.handleInputChange}/>
                            <Select title="Maksumäär:"
                                    name='vat'
                                    data={TAXIES}
                                    collId='kood'
                                    value={self.docData.vat || ''}
                                    defaultValue={self.docData.vat}
                                    ref="select-vat"
                                    btnDelete={isEditeMode}
                                    onChange={self.handleInputChange}
                                    readOnly={!isEditeMode}/>
                            <InputNumber title="Hind: "
                                         name='hind'
                                         ref="input-hind"
                                         value={Number(self.docData.hind || null)}
                                         readOnly={!isEditeMode}
                                         onChange={self.handleInputChange}/>
                            <Select title="Mõttühik:"
                                    name='uhik'
                                    data={UHIK}
                                    collId='kood'
                                    value={self.docData.uhik || ''}
                                    defaultValue={self.docData.uhik}
                                    ref="select-uhik"
                                    btnDelete={isEditeMode}
                                    onChange={self.handleInputChange}
                                    readOnly={!isEditeMode}/>
                        </div>
                    </div>
                    <div style={styles.docRow}>
                        <div style={styles.docColumn}>
                            <InputDate title='Kehtiv kuni:'
                                       name='valid'
                                       value={self.docData.valid}
                                       ref='input-valid'
                                       readOnly={!isEditeMode}
                                       onChange={self.handleInputChange}/>

                        </div>
                    </div>

                    <div style={styles.docRow}>
                        <TextArea title="Muud"
                                  name='muud'
                                  ref="textarea-muud"
                                  onChange={self.handleInputChange}
                                  value={self.docData.muud || ''}
                                  readOnly={!isEditeMode}/>
                    </div>
                </div>
            </div>
        );
    }

}

Nomenclature.propTypes = {
    docId: PropTypes.number,
    initData: PropTypes.object,
    userData: PropTypes.object
};

Nomenclature.defaultProps = {
    initData: {},
    userData: {}
};


module.exports = (Nomenclature);