"""Validate a stored WaaS artifact pair structurally (not EN-16931/PDF-A)."""
import base64
import datetime
import json
import os
import subprocess
import xml.etree.ElementTree as ET

name = os.environ.get('WAAS_TEST_DB_NAME', 'saaserp_test')
query = "SELECT encode(pdf,'base64'),encode(xml,'base64'),encode(convert_to(snapshot::text,'UTF8'),'base64') FROM waas_invoice_documents ORDER BY approved_at DESC LIMIT 1"
result = subprocess.run(['docker', 'exec', 'saaserp-waas-test', 'psql', '-U', 'postgres', '-d', name, '-At', '-F', '|', '-c', query], capture_output=True, check=True, text=True)
encoded_pdf, encoded_xml, encoded_snapshot = result.stdout.strip().split('|')
pdf, xml = base64.b64decode(encoded_pdf), base64.b64decode(encoded_xml)
snapshot = json.loads(base64.b64decode(encoded_snapshot))
root = ET.fromstring(xml)
assert root.tag == '{urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100}CrossIndustryInvoice'
xml_id = root.find('{urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100}ExchangedDocument/{urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100}ID')
assert xml_id is not None and xml_id.text
info = subprocess.run(['pdfinfo', '-'], input=pdf, capture_output=True, check=True)
text = subprocess.run(['pdftotext', '-layout', '-', '-'], input=pdf, capture_output=True, check=True).stdout.decode()
assert f'Rechnung {xml_id.text}' in text
issue = datetime.date.fromisoformat(snapshot['invoice']['created_at'][:10])
due = datetime.date.fromisoformat(snapshot['invoice']['due_date'])
assert due >= issue
ns = {'rsm': 'urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100',
      'ram': 'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100',
      'udt': 'urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100'}
xml_issue = root.findtext('./rsm:ExchangedDocument/ram:IssueDateTime/udt:DateTimeString', namespaces=ns)
xml_due = root.findtext('.//ram:SpecifiedTradePaymentTerms/ram:DueDateDateTime/udt:DateTimeString', namespaces=ns)
assert xml_issue == issue.strftime('%Y%m%d') and xml_due == due.strftime('%Y%m%d')
assert f'Datum: {issue:%d.%m.%Y}' in text and f'Fällig am: {due:%d.%m.%Y}' in text
assert set(snapshot['customer']) == {'name', 'address', 'leitweg_id'}
assert set(snapshot['tenant']) == {'name', 'company_address', 'company_tax_id', 'company_iban'}
assert 'Website' in text or 'Site Care' in text
print(f'PDF: {len(pdf)} bytes; XML: {len(xml)} bytes; XML parsed; pdfinfo:')
print(info.stdout.decode())
print('PDF text excerpt:', text[:500])
print('NO PDF/A-3, Factur-X, EN-16931 or XRechnung conformity validated.')
