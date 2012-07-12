<?xml version="1.0" encoding="ISO-8859-1"?>
<!--
  - snipscrape
  - http://snarfed.org/snipscrape
  - Copyright 2004 Ryan Barrett <snipscrape@ryanb.org>
  -
  - File: snipscrape.xslt
  -
  - Snipscrape converts html pages generated by SnipSnap 0.4.2 to xml files
  - suitable for importing into SnipSnap. This can be useful if, for example,
  - your SnipSnap database was corrupted, and you'd like to recreate it from
  - browser cache or, say, google's cache. Or you could use it to steal pages
  - from another site that runs SnipSnap. :P
  -
  - Snipscrape is only supported on SnipSnap 0.4.2, and has not been tested on
  - other versions. It should work, but your mileage may vary.
  -
  - Example usage:
  -
  - $ snipscrape.sh snip1.html snip2.html > snips.xml
  -
  - There are a few things that can cause xsltproc to choke. One is mismatched
  - opening and closing tags, which can happen if you have xml or html code
  - inside {code} macros on the page.
  -
  - TODO: use call-template instead of apply-templates
  - TODO: {isbn} macro (it's not in an identifying div or other element)
  -  for the record, it generates:
  -  (<a href="...">Amazon</a> | <a href="...">BN</a> | <a href="...">etc.</a>)
  -
  -
  - This program is free software; you can redistribute it and/or modify it
  - under the terms of the GNU General Public License as published by the Free
  - Software Foundation; either version 2 of the License, or (at your option)
  - any later version.
  -
  - This program is distributed in the hope that it will be useful, but WITHOUT
  - ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  - FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
  - more details.
  -
  - You should have received a copy of the GNU General Public License along
  - with this program; if not, write to the Free Software Foundation, Inc., 59
  - Temple Place, Suite 330, Boston, MA 02111-1307 USA
  -->

<xsl:transform version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output omit-xml-declaration="yes" indent="yes" />

<xsl:variable name="snipname"
  select='normalize-space(/html/body/div[@id="page-wrapper"]
           /div[@id="page-content"]/div[@class="snip-wrapper"]
           /div[@class="snip-title"]/h1[@class="snip-name"]/text())' />

<xsl:variable name="snipname_encoded"
  select='translate($snipname, " ", "+")' />

<xsl:template match='/'>
  <xsl:apply-templates mode="main"
    select='/html/body/div[@id="page-wrapper"]/div[@id="page-content"]
            /div[@class="snip-wrapper"]' />
</xsl:template>


<!--=============
  - MAIN TEMPLATE
  -
  - This template contains the top-level layout of a snip element. It invokes
  - all of the other templates in the transformation.
  =============-->
<xsl:template mode="main" match='div[@class="snip-wrapper"]'>
<snip>
  <xsl:apply-templates
    select='//div[@class="snip-title"]/h1[@class="snip-name"]'
    mode="snip-title" />

  <content
    ><xsl:apply-templates mode="content" select='div[@class="snip-content"]' />
  </content>

  <xsl:apply-templates
    select='//div[@class="snip-info"]'
    mode="snip-info" />

  <backLinks>
    <xsl:apply-templates
      select='div[@class="snip-backlinks"]/ul'
      mode="backlinks" />
  </backLinks>

  <snipLinks>
    <xsl:apply-templates
      select='div[@class="snip-sniplinks"]/table'
      mode="sniplinks" />
  </snipLinks>

  <attachments>
    <xsl:apply-templates mode="attachments"
       select='//div[@class="snip-attachments"]' />
  </attachments>

  <!-- these elements are currently unsupported -->
  <cTime />
  <mTime />
  <labels />
  <permissions />
</snip>
</xsl:template>



<!--==================
  - METADATA TEMPLATES
  -
  - These templates are applied to the snip's metadata. They handle things like
  - the snip's owner, creation time, sniplinks, backlinks, attachments, etc.
  - They don't handle the snip's content.
  ==================-->
<!--
  - Converts the snip-title div to name and (optionally) commentSnip elements.
  -->
<xsl:template mode="snip-title" match='h1[@class="snip-name"]'>
  <name><xsl:value-of select='$snipname'/></name>

  <xsl:if test='span[@class="snip-commented-snip"]'>
    <commentSnip>
      <xsl:value-of select='span[@class="snip-commented-snip"]/a' />
    </commentSnip>
  </xsl:if>
</xsl:template>


<!--
  - Converts the snip-info div to user (cUser, mUser, oUser) and viewCount
  - elements.
  -
  - The snip-info div looks like this:
  - <div class="snip-info">
  -   Created by <a href="http://snarfed.org/ryan">ryan</a>. Last edited
  -   by <a href="http://snarfed.org/ryan">maulik</a> 2 days ago. Viewed
  -   16 times.
  - </div>
  -
  - Note that the match attribute is required; otherwise the template won't be
  - applied. (I don't know why. :P)
  -->
<xsl:template mode="snip-info" match='div[@class="snip-info"]'>
  <xsl:variable name="creator" select="a[1]" />
  <xsl:variable name="last_editor" select="a[2]" />

  <cUser> <xsl:value-of select="$creator" /> </cUser>
  <mUser> <xsl:value-of select="$last_editor" /> </mUser>
  <oUser> <xsl:value-of select="$creator" /> </oUser>

  <viewCount>
    <!-- note the . argument, which returns the current element's text -->
    <xsl:value-of
      select='substring-before(substring-after(., "Viewed "), " times.")' />
  </viewCount>
</xsl:template>


<!--
  - Converts the snip-backlinks div to a backLinks element.
  -->
<xsl:template mode="backlinks" match='ul'>
  <xsl:for-each select='li'>
    <xsl:value-of select='span[@class="content"]' /> :
    <xsl:value-of select='span[@class="count"]' /> |
  </xsl:for-each>
</xsl:template>


<!--
  - Converts the snip-sniplinks div to a snipLinks element.
  - I believe the number is a count of how many times the link has been clicked
  - on, but since the count isn't in the html, we just infer an approximate,
  - relative count by the ordering, high to low.
  -->
<xsl:template mode="sniplinks" match='table'>
  <xsl:for-each select='tr/td'>
    <xsl:value-of select='a' />
    <xsl:text> : </xsl:text>
    <xsl:value-of select='last() - position() + 1' />
    <xsl:text> | </xsl:text>
  </xsl:for-each>
</xsl:template>


<!--
  - Converts the snip-attachments div to an attachments element.
  -
  - The format of the attachments div in the HTML is:
  - <div class="snip-attachments">
  -   <a href="../space/snipname/filename">filename</a> (123)<br/>
  -   ...
  - </div>
  -
  - The number in parentheses is the size of the attachment, in bytes.
  -
  - The format of the attachments element in the XML is:
  - <attachments>
  -   <name>filename</name>
  -   <content-type>application/foobar</content-type>
  -   <size>123</size>
  -   <date>1083779989391</date>
  -   <location>snipname/filename</location>
  - </attachments>
  -
  - Note that the link in the HTML file points to ../space/snipname/filename,
  - but the location element in the XML is snipname/filename (no ../space/).
  - Also, the date is not currently recovered from the html file.
  -
  - Note: the content-type is not inferred for attachments with more than one
  - period in their file name.
  --> 
<xsl:template mode="attachments" match='div[@class="snip-attachments"]'>
  <xsl:call-template name="attachment">
    <xsl:with-param name="txt" select="." />
    <xsl:with-param name="number" select="1" />
  </xsl:call-template>
</xsl:template>

<!--
  - This template works recursively so that it can parse the file sizes out of
  - the div's text. It parses a single attachment, then calls itself to parse
  - the rest.
  -->
<xsl:template name="attachment">
  <xsl:param name="txt" />
  <xsl:param name="number" />
  <xsl:variable name="filename" select="a[@href][$number]" />

  <!-- base case; continue only if there are more file sizes in parentheses -->
  <xsl:if test='contains($txt, ")")'>
    <xsl:text>&#x3c;attachment&#x3e;</xsl:text>

    <xsl:text>&#x3c;name&#x3e;</xsl:text>
      <xsl:value-of select='$filename' />
    <xsl:text>&#x3c;/name&#x3e;</xsl:text>

    <xsl:text>&#x3c;size&#x3e;</xsl:text>
      <xsl:value-of select='substring-before(
                              substring-after($txt, "("), ")")' />
    <xsl:text>&#x3c;/size&#x3e;</xsl:text>

    <xsl:text>&#x3c;location&#x3e;</xsl:text>
      <xsl:value-of select='concat($snipname_encoded, "/", $filename)' />
    <xsl:text>&#x3c;/location&#x3e;</xsl:text>

    <xsl:text>&#x3c;content-type&#x3e;</xsl:text>
      <!-- infer the content type from the extension -->
      <xsl:variable name="ext" select='substring-after($filename, ".")'/>
      <xsl:choose>
        <xsl:when test='$ext="cpp" or $ext="java" or $ext="py"'
          >text/plain</xsl:when>
        <xsl:when test='$ext="html"'>text/html</xsl:when>
        <xsl:when test='$ext="dll" or $ext="exe" or $ext="jar"'
          >application/octet-stream</xsl:when>
        <xsl:when test='$ext="gz" or $ext="tgz"'
          >application/x-gzip</xsl:when>
        <xsl:when test='$ext="bz2"'>application/x-bzip2</xsl:when>
        <xsl:when test='$ext="zip"'>application/zip</xsl:when>
        <xsl:when test='$ext="pdf"'>application/pdf</xsl:when>
        <xsl:when test='$ext="jpg" or $ext="jpeg"'>image/jpeg</xsl:when>
        <xsl:when test='$ext="png"'>image/png</xsl:when>
        <xsl:when test='$ext="gif"'>image/gif</xsl:when>
        <xsl:when test='$ext="doc"'>application/msword</xsl:when>
        <xsl:otherwise><!-- unknown type, so leave blank --></xsl:otherwise>
      </xsl:choose>
    <xsl:text>&#x3c;/content-type&#x3e;</xsl:text>

    <xsl:text>&#x3c;date&#x3e;1&#x3c;/date&#x3e;</xsl:text>

    <xsl:text>&#x3c;/attachment&#x3e;</xsl:text>

    <!-- recursive step - parse the rest of the attachments -->
    <xsl:call-template name="attachment">
      <xsl:with-param name="txt" select='substring-after($txt, ")")' />
      <xsl:with-param name="number" select='$number + 1' />
    </xsl:call-template>
  </xsl:if>
</xsl:template>


<!--================
  - LAYOUT TEMPLATES
  -
  - These templates are applied to the snip's content. They handle macros that
  - impose structure on the content, such as the {table} macro, bullet points,
  - etc. They're mostly "reverse macros," ie converting backwards from a
  - macro's output to its original syntax. They're separated from the
  - formatting templates because they may contain embedded text that needs to
  - be processed by the formatting macros.
  -
  - Many of them have unusual punctuation and whitespace; this is an attempt to
  - preserve the original formatting (in which whitespace is significant) and
  - still keep the code somewhat readable.
  ================-->
<!--
  - Removes the contents of the attachments div from the output, (It's handled
  - by its own template; see above.
  -->
<xsl:template mode="content" match='//div[@class="snip-attachments"]'>
</xsl:template>


<!--
  - Converts <ul><li>... to bullet points. (The attribute of the ul element
  - indicates the type of bullet point.)
  -->
<xsl:template mode="content" match='//ul'>
  <xsl:for-each select="li">
    <xsl:text>

</xsl:text>

    <xsl:choose>
      <!-- the classes used in snarfed (so far) are minus, star, and list -->
      <xsl:when test='@class="minus" or @class="star"'>
        <xsl:text>- </xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>* </xsl:text>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:apply-templates mode="content" select="." />

  </xsl:for-each>
</xsl:template>


<!--
  - Converts tables back to table macros. A table macro looks like this:
  -
  -  {table}
  -  This | is | the | header
  -  A | B | C | D
  -  E | F | G | H
  -  {table}
  -
  - which generates:
  -
  -  This       is      the     header
  -  A          B       C           D
  -  E          F       G           H
  -->
<xsl:template mode="content" match='//table[@class="wiki-table"]'>
  <xsl:text> {table}
  </xsl:text>

  <xsl:for-each select="tr">
    <xsl:for-each select="th | td">
      <xsl:apply-templates mode="content" select="." />
      <xsl:if test="position() != last()">
        <xsl:text> | </xsl:text>
      </xsl:if>
    </xsl:for-each>

    <xsl:text>  <!-- insert carriage return at end of each row -->
    </xsl:text>
  </xsl:for-each>

  <xsl:text> {table}
  </xsl:text>
</xsl:template>


<!-- 
  - Converts "code" divs to enclosing {code} macros.
  -->
<xsl:template mode="content" match='//div[@class="code"]'>
  <xsl:text> {code}
  </xsl:text>
  <xsl:apply-templates mode="content" select='pre' />
  <xsl:text> {code}
  </xsl:text>
</xsl:template>


<!--====================
  - FORMATTING TEMPLATES
  -
  - These templates are applied to the snip's content. They handle macros that
  - format text, such as bold, italics, line breaks, links, etc.
  -
  - Many of them have unusual punctuation and whitespace; this is an attempt to
  - preserve the original formatting (in which whitespace is significant) and
  - still keep the code somewhat readable.
  ====================-->
<!--
  - Converts <h3 class="heading-1"> to "1 ...".
  -->
<xsl:template mode="content" match='//h3[@class="heading-1"]'>
  <xsl:text>1 </xsl:text>
  <xsl:value-of select="." />
  <xsl:text>
  </xsl:text>
</xsl:template>


<!--
  - Converts hard line breaks (<br/>'s) to \\'s.
  -->
<xsl:template mode="content" match="//br">
  <xsl:text> \\
  </xsl:text>
</xsl:template>


<!--
  - Converts natural line breaks (<p class="paragraph" />'s) to two carriage
  - returns.
  -->
<xsl:template mode="content" match='//p[@class="paragraph"]'>
  <xsl:text>

  </xsl:text>
</xsl:template>


<!--
  - Converts text in <b class="bold"> tags to the bold macro (ie
  - enclosed in __'s).
  -->
<xsl:template mode="content" match='//b[@class="bold"]'>
  <xsl:text>__</xsl:text>
  <xsl:value-of select="." />
  <xsl:text>__</xsl:text>
</xsl:template>


<!--
  - Converts text in <i class="italic"> tags to the italic macro (ie
  - enclosed in ~~'s).
  -->
<xsl:template mode="content" match='//i[@class="italic"]'>
  <xsl:text>~~</xsl:text>
  <xsl:value-of select="." />
  <xsl:text>~~</xsl:text>
</xsl:template>


<!--
  - Converts text in <strike class="strike"> tags to the strike macro (ie
  - enclosed in two hyphens).
  -->
<xsl:template mode="content" match='//strike[@class="strike"]'>
  <xsl:text>--</xsl:text>
  <xsl:value-of select="." />
  <xsl:text>--</xsl:text>
</xsl:template>

<!-- 
  - Converts img tags back to image macros. Supports external images and the
  - link parameter to the image macros.
  -->
<xsl:template mode="content" match="//img">
  <!-- ignore snipsnap's own silly images -->
  <xsl:if test='not(contains(@src, "external-link.png")
                    or contains(@src, "permalink.png")
                    or contains(@src, "person-icon.png")
                    or contains(@src, "comment.png")
                    or contains(@src, "commented.png")
                    or contains(@src, "comment-icon.png"))'>

    <xsl:text> {image:</xsl:text>


    <xsl:choose>
      <xsl:when test='contains(@src, concat("space/", $snipname_encoded))'>
        <!-- it's an attached image. the img src will look like:
          -    http://snarfed.org/snip_name/filename.jpg
          -  ...we want to extract the filename.
          -->
        <xsl:value-of
          select='substring-after(substring-after(@src, "space/"), "/")' />
      </xsl:when>

      <xsl:otherwise>
        <!-- it's an external image, use the full URL -->
        <xsl:value-of select='@src' />
      </xsl:otherwise>
    </xsl:choose>

    <!-- if it's in a link, add the link param -->
    <xsl:if test="../@href">
      <xsl:text>|link=</xsl:text>
      <xsl:value-of select='../@href' />
    </xsl:if>
    <xsl:text>} </xsl:text>
  </xsl:if>
</xsl:template>


<!--
  - These macros converts links back to [...] macros if they point to a snip,
  - links if their content is their same as their href, {link} macros if not
  - but they still point to something, and {anchor} macros if they're just an
  - anchor.
  -->
<xsl:template mode="content" match="//a[@name and not(@href)]">
  <xsl:text> {anchor:</xsl:text>
    <xsl:value-of select="@name" />
  <xsl:text>} </xsl:text>
</xsl:template>

<xsl:template mode="content" match="//a[@href and not(img)]">
  <xsl:choose>
    <!-- is it a [...] macro? -->
    <xsl:when test='.=$snipname'>
      <xsl:text>[</xsl:text>
      <xsl:value-of select='$snipname' />
      <xsl:text>]</xsl:text>
    </xsl:when>

    <!-- it's a {link} macro -->
    <xsl:otherwise>
      <xsl:text>{link:</xsl:text>
        <xsl:value-of select="." />
      <xsl:text>|</xsl:text>
        <xsl:value-of select="@href" />
      <xsl:text>}</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template mode="content" match="//a[@href and .=@href]">
  <xsl:value-of select="." />
</xsl:template>


</xsl:transform>