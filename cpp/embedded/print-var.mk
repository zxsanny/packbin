# Included after cpp/Makefile: `make -f Makefile -f embedded/print-var.mk print-VECTOR_TESTS`.
print-%:
	@echo $($*)
