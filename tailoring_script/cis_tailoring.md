# CIS Tailoring for RHEL 9 (Bootc Images)

A CIS tailoring file is a customized OpenSCAP profile derived from the upstream CIS benchmark for Red Hat Enterprise Linux 9. It allows us to explicitly:

- enable or disable individual CIS rules

- apply the same security intent consistently during both image hardening and compliance scanning

Rather than modifying the upstream CIS profile directly, tailoring provides a controlled, versioned overlay that reflects how the benchmark is applied in our environment.

### Tailoring inputs and structure

The tailoring process is driven by the following components:

1. tailoring.yaml (inputs)

   A human-readable declaration of:
   - which CIS rules are enabled or disabled
   - values of the CIS rules

2. ssg_cs9_ds_tailoring_template.xml

   A template that maps the YAML inputs into a valid OpenSCAP tailoring document.

3. generate_tailoring.sh

   A helper script that:
   - reads tailoring.yaml
   - renders a finalized tailoring XML
   - outputs a consumable OpenSCAP tailoring file

This separation allows security intent to be reviewed and maintained in YAML, while still producing a standards-compliant XML artifact for OpenSCAP tooling.

# How to generate the tailored CIS profile

How to generate the tailored CIS profile

```
chmod +x tailoring_script/generate_tailoring.sh
./tailoring_script/generate_tailoring.sh
```

This generates the tailored CIS profile at:

```
/system_files/usr/share/ssg_cs9_ds_tailoring_generated.xml
```

This file represents the authoritative CIS policy for the bootc images built from this repository.

# How to tailoring file is used

The generated tailoring file is used in two distinct but related stages:

1. Image hardening (build time)

   During image build, the tailoring file is referenced by the hardening scripts
   (e.g. `build_scripts/39-harden-os-rhel9.sh`) to ensure that the applied
   configuration aligns with the intended CIS profile.

   This ensures that:

   - hardening actions match the declared CIS intent
   - unnecessary or incompatible controls are not applied

2. Compliance scanning (validation time)

   The same tailoring file is used during OpenSCAP scans to evaluate compliance.

   ```
   oscap xccdf eval \
   --profile <tailored-profile> \
   --tailoring-file /system_files/usr/share/ssg_cs9_ds_tailoring_generated.xml \
   /usr/share/xml/scap/ssg/content/ssg-cs9-ds.xml
   ```

Using the same tailoring file for both hardening and scanning guarantees:

- no mismatch between applied controls and evaluated controls
- reproducible CIS results across builds


