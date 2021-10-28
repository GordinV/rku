'use strict';
const React = require('react');
const PropTypes = require('prop-types');

const DocumentTemplate = require('./../../documentTemplate/index.jsx'),
    TextArea = require('../../../components/text-area/text-area.jsx'),
    InputDate = require('../../../components/input-date/input-date.jsx'),
    Select = require('../../../components/select/select.jsx'),
    Loading = require('./../../../components/loading/index.jsx'),
    ButtonEdit = require('../../../components/button-register/button-register-edit/button-register-edit.jsx');

const LIB_OBJS = require('./../../../../config/constants').REKL.LIB_OBJS;

const styles = require('./styles');

/**
 * Класс реализует документ справочника признаков.
 */
class Rekl extends React.PureComponent {
    constructor(props) {
        super(props);

        this.state = {
            docId: props.docId ? props.docId : Number(props.match.params.docId),
            loadedData: false
        };
        this.renderer = this.renderer.bind(this);
        this.btnCheckLinkClick = this.btnCheckLinkClick.bind(this);
        this.link = '';
    }

    render() {
        return (
            <DocumentTemplate docId={this.state.docId}
                              ref='document'
                              docTypeId='REKL'
                              libs={LIB_OBJS}
                              module={this.props.module}
                              initData={this.props.initData}
                              userData={this.props.userData}
                              renderer={this.renderer}
                              focusElement={'input-alg_kpv'}
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
        this.link = self.docData.link;
        return (
            <div style={styles.doc}>
                <div style={styles.docRow}>
                    <div style={styles.docColumn}>

                        <InputDate title='Alg. Kuupäev '
                                   name='alg_kpv'
                                   value={self.docData.alg_kpv}
                                   ref='input-alg_kpv'
                                   readOnly={!self.state.edited}
                                   onChange={self.handleInputChange}/>
                        <InputDate title='Lõpp kuupäev '
                                   name='lopp_kpv'
                                   value={self.docData.lopp_kpv}
                                   ref="input-lopp_kpv"
                                   readOnly={!self.state.edited}
                                   onChange={self.handleInputChange}/>
                        <Select title="Reklaamiandja:"
                                libs="asutused"
                                name='asutusid'
                                data={self.libs['asutused']}
                                value={self.docData.asutusid || 0}
                                defaultValue={self.docData.asutus}
                                onChange={self.handleInputChange}
                                collId={'id'}
                                readOnly={!self.state.edited}/>
                    </div>
                </div>
                <div style={styles.docRow}>

                    <TextArea title="Nimetus"
                              name='nimetus'
                              ref="textarea-nimetus"
                              onChange={self.handleInputChange}
                              value={self.docData.nimetus || ''}
                              readOnly={!self.state.edited}/>
                </div>
                <div style={styles.docRow}>
                    <TextArea title="Link"
                              name='link'
                              ref="textarea-link"
                              onChange={self.handleInputChange}
                              value={self.docData.link || ''}
                              readOnly={!self.state.edited}/>
                </div>
                <div style={styles.docRow}>
                    <ButtonEdit
                        ref='btnEdit'
                        value={'Kontrolli link'}
                        onClick={this.btnCheckLinkClick}
                        show={!self.state.edited}
                        style={styles.btnEdit}
                        disabled={false}
                    />
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

    btnCheckLinkClick() {
        window.open(this.link, "_blank")
    }

}

Rekl.propTypes = {
    docId: PropTypes.number,
    initData: PropTypes.object
};

Rekl.defaultProps = {
    initData: {},
};


module.exports = (Rekl);
