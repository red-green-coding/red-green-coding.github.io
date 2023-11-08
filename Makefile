# Define a wildcard pattern to find all .plantuml files recursively
PLANTUML_FILES := $(shell find assets/plantuml -type f -name '*.plantuml')

# Define a rule to generate PNG files from PlantUML files
%.png: %.plantuml
	docker run --rm -v $(PWD):/data dstockhammer/plantuml $<

# Define the default target and the list of PNG files to build
all: $(PLANTUML_FILES:.plantuml=.png)

# Clean rule to remove generated PNG files
clean:
	find assets/plantuml -name "*.png"|xargs rm -f

.PHONY: all clean