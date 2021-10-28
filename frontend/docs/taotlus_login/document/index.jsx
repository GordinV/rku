'use strict';
const React = require('react');
const PropTypes = require('prop-types');

const DocumentTemplate = require('./../../documentTemplate/index.jsx'),
    InputText = require('../../../components/input-text/input-text.jsx'),
    InputDate = require('../../../components/input-date/input-date.jsx'),
    TextArea = require('../../../components/text-area/text-area.jsx'),
    Loading = require('./../../../components/loading/index.jsx');

const styles = require('./styles');

/**
 * Класс реализует документ справочника признаков.
 */
class TaotlusLogin extends React.PureComponent {
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
                              docTypeId='TAOTLUS_LOGIN'
                              module={this.props.module}
                              initData={this.props.initData}
                              userData={this.props.userData}
                              renderer={this.renderer}
                              focusElement={'input-kasutaja'}
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

        return (
            <div style={styles.doc}>
                <div style={styles.docColumn}>
                    <div style={styles.docRow}>
                        <InputDate title='Kuupäev:'
                                   name='kpv'
                                   value={self.docData.kpv}
                                   ref='input-kpv'
                                   readOnly={true}
                                   onChange={self.handleInputChange}/>
                    </div>
                    <div style={styles.docRow}>
                        <InputText title="Kasutaja nimi "
                                   name='kasutaja'
                                   ref="input-kasutaja"
                                   readOnly={true}
                                   value={self.docData.kasutaja || ''}
                                   onChange={self.handleInputChange}/>
                    </div>
                    <div style={styles.docRow}>
                        <InputText title="Nimi"
                                   name='nimi'
                                   ref="input-nimi"
                                   readOnly={!self.state.edited}
                                   value={self.docData.nimi || ''}
                                   onChange={self.handleInputChange}/>
                    </div>
                    <div style={styles.docRow}>
                        <InputText title="Aadress"
                                   name='aadress'
                                   ref="input-aadress"
                                   readOnly={true}
                                   value={self.docData.aadress || ''}
                                   onChange={self.handleInputChange}/>
                    </div>
                    <div style={styles.docRow}>
                        <InputText title="E-mail"
                                   name='email'
                                   ref="input-email"
                                   readOnly={true}
                                   value={self.docData.email || ''}
                                   onChange={self.handleInputChange}/>
                    </div>
                    <div style={styles.docRow}>
                        <InputText title="Telefon"
                                   name='tel'
                                   ref="input-tel"
                                   readOnly={!self.state.edited}
                                   value={self.docData.tel || ''}
                                   onChange={self.handleInputChange}/>
                    </div>
                </div>
                <div style={styles.docRow}>
                    <TextArea title="Muud"
                              name='muud'
                              ref="textarea-muud"
                              onChange={self.handleInputChange}
                              value={self.docData.muud || ''}
                              readOnly={!self.state.edited}/>
                </div>
            </div>
        );
    }

}

TaotlusLogin.propTypes = {
    docId: PropTypes.number,
    initData: PropTypes.object
};

TaotlusLogin.defaultProps = {
    initData: {},
};


module.exports = (TaotlusLogin);
