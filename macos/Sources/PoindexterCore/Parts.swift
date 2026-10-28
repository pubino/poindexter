// Static PresentationML parts shared by every generated deck.

enum Parts {
    static let rootRels = """
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
        <Relationship Id="rId1" \
        Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" \
        Target="ppt/presentation.xml"/>\
        <Relationship Id="rId2" \
        Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" \
        Target="docProps/core.xml"/>\
        <Relationship Id="rId3" \
        Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" \
        Target="docProps/app.xml"/>\
        </Relationships>
        """

    static let presProps = "<p:presentationPr \(XML.ns)/>"

    static let viewProps = """
        <p:viewPr \(XML.ns)><p:normalViewPr><p:restoredLeft sz="15620"/>\
        <p:restoredTop sz="94660"/></p:normalViewPr><p:gridSpacing cx="76200" cy="76200"/></p:viewPr>
        """

    static let tableStyles = """
        <a:tblStyleLst xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" \
        def="{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}"/>
        """

    static let clrMap = """
        bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" \
        accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" \
        hlink="hlink" folHlink="folHlink"
        """

    static let slideMaster = """
        <p:sldMaster \(XML.ns)><p:cSld>\
        <p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg>\
        <p:spTree>\(XML.groupHeader)</p:spTree></p:cSld>\
        <p:clrMap \(clrMap)/>\
        <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>\
        <p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles>\
        </p:sldMaster>
        """

    static let slideMasterRels = XML.relationships([
        ["rId1", "slideLayout", "../slideLayouts/slideLayout1.xml"],
        ["rId2", "theme", "../theme/theme1.xml"],
    ])

    static let slideLayout = """
        <p:sldLayout \(XML.ns) type="blank" preserve="1"><p:cSld name="Blank">\
        <p:spTree>\(XML.groupHeader)</p:spTree></p:cSld>\
        <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>
        """

    static let slideLayoutRels = XML.relationships([
        ["rId1", "slideMaster", "../slideMasters/slideMaster1.xml"]
    ])

    static let notesMaster = """
        <p:notesMaster \(XML.ns)><p:cSld>\
        <p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg>\
        <p:spTree>\(XML.groupHeader)\
        <p:sp><p:nvSpPr><p:cNvPr id="2" name="Slide Image Placeholder 1"/>\
        <p:cNvSpPr><a:spLocks noGrp="1" noRot="1" noChangeAspect="1"/></p:cNvSpPr>\
        <p:nvPr><p:ph type="sldImg" idx="2"/></p:nvPr></p:nvSpPr>\
        <p:spPr><a:xfrm><a:off x="685800" y="1143000"/><a:ext cx="5486400" cy="3086100"/></a:xfrm>\
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:sp>\
        <p:sp><p:nvSpPr><p:cNvPr id="3" name="Notes Placeholder 2"/>\
        <p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>\
        <p:nvPr><p:ph type="body" sz="quarter" idx="3"/></p:nvPr></p:nvSpPr>\
        <p:spPr><a:xfrm><a:off x="685800" y="4400550"/><a:ext cx="5486400" cy="3600450"/></a:xfrm>\
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\
        <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:endParaRPr lang="en-US"/></a:p></p:txBody></p:sp>\
        </p:spTree></p:cSld>\
        <p:clrMap \(clrMap)/>\
        <p:notesStyle><a:lvl1pPr marL="0" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" \
        latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1200" kern="1200">\
        <a:solidFill><a:schemeClr val="tx1"/></a:solidFill>\
        <a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/>\
        </a:defRPr></a:lvl1pPr></p:notesStyle>\
        </p:notesMaster>
        """

    static let notesMasterRels = XML.relationships([["rId1", "theme", "../theme/theme2.xml"]])

    private static func color(_ name: String, _ hex: String) -> String {
        "<a:\(name)><a:srgbClr val=\"\(hex)\"/></a:\(name)>"
    }

    private static let solid = "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>"
    private static let line = "<a:ln w=\"6350\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:ln>"
    private static let effect = "<a:effectStyle><a:effectLst/></a:effectStyle>"

    static let theme = """
        <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">\
        <a:themeElements><a:clrScheme name="Office">\
        <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>\
        <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>\
        \(color("dk2", "44546A"))\(color("lt2", "E7E6E6"))\(color("accent1", "4472C4"))\
        \(color("accent2", "ED7D31"))\(color("accent3", "A5A5A5"))\(color("accent4", "FFC000"))\
        \(color("accent5", "5B9BD5"))\(color("accent6", "70AD47"))\(color("hlink", "0563C1"))\
        \(color("folHlink", "954F72"))</a:clrScheme>\
        <a:fontScheme name="Office">\
        <a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>\
        <a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>\
        </a:fontScheme>\
        <a:fmtScheme name="Office">\
        <a:fillStyleLst>\(solid)\(solid)\(solid)</a:fillStyleLst>\
        <a:lnStyleLst>\(line)\(line)\(line)</a:lnStyleLst>\
        <a:effectStyleLst>\(effect)\(effect)\(effect)</a:effectStyleLst>\
        <a:bgFillStyleLst>\(solid)\(solid)\(solid)</a:bgFillStyleLst>\
        </a:fmtScheme></a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/></a:theme>
        """
}
